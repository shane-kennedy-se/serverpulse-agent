#!/usr/bin/env python3
"""
ServerPulse Linux Agent
Real-time monitoring agent for Linux systems
"""

import os
import sys
import time
import json
import logging
import signal
import threading
from datetime import datetime
from pathlib import Path

import psutil
import requests
import yaml
import schedule
from setproctitle import setproctitle

from collectors.system_metrics import SystemMetricsCollector
from collectors.service_monitor import ServiceMonitor
from collectors.crash_detector import CrashDetector
from collectors.log_monitor import LogMonitor
from communication.api_client import APIClient
from utils.config import Config
from utils.logger import setup_logger


class ServerPulseAgent:
    """Main agent class that orchestrates all monitoring activities"""
    
    def __init__(self, config_path="/etc/serverpulse-agent/config.yml"):
        self.config_path = config_path
        self.config = None
        self.running = False
        self.logger = None
        
        # Initialize collectors
        self.system_collector = None
        self.service_monitor = None
        self.crash_detector = None
        self.log_monitor = None
        self.api_client = None
        
        # Threading
        self.threads = []
        self.stop_event = threading.Event()
        
    def initialize(self):
        """Initialize the agent with configuration and collectors"""
        try:
            # Load configuration
            self.config = Config(self.config_path)
            
            # Setup logging
            self.logger = setup_logger(
                self.config.get('logging.level', 'INFO'),
                self.config.get('logging.file', '/var/log/serverpulse-agent.log')
            )
            
            self.logger.info("Initializing ServerPulse Agent...")
            
            # Initialize API client
            self.api_client = APIClient(
                endpoint=self.config.get('server.endpoint'),
                auth_token=self.config.get('server.auth_token'),
                agent_id=self.config.get('server.agent_id'),
                logger=self.logger
            )
            
            # Register agent with server
            if not self.api_client.register_agent():
                self.logger.error("Failed to register agent with server")
                return False
            
            # Initialize collectors
            self.system_collector = SystemMetricsCollector(
                self.config.get('collection.interval', 30),
                self.logger
            )
            
            self.service_monitor = ServiceMonitor(
                self.config.get('monitoring.services', []),
                self.logger
            )
            
            self.crash_detector = CrashDetector(
                self.config.get('monitoring.log_paths', ['/var/log/syslog', '/var/log/kern.log']),
                self.logger
            )
            
            self.log_monitor = LogMonitor(
                self.config.get('monitoring.custom_logs', []),
                self.logger
            )
            
            self.logger.info("ServerPulse Agent initialized successfully")
            return True
            
        except Exception as e:
            if self.logger:
                self.logger.error(f"Failed to initialize agent: {e}")
            else:
                print(f"Failed to initialize agent: {e}")
            return False
    
    def start(self):
        """Start the monitoring agent"""
        if not self.initialize():
            sys.exit(1)
        
        self.logger.info("Starting ServerPulse Agent...")
        self.running = True
        
        # Set process title
        setproctitle("serverpulse-agent")
        
        # Setup signal handlers
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
        
        try:
            # Start monitoring threads
            self._start_monitoring_threads()
            
            # Schedule periodic tasks
            schedule.every(self.config.get('collection.interval', 30)).seconds.do(self._collect_and_send_metrics)
            schedule.every(60).seconds.do(self._send_heartbeat)
            
            # Main loop
            while self.running:
                schedule.run_pending()
                time.sleep(1)
                
        except Exception as e:
            self.logger.error(f"Error in main loop: {e}")
        finally:
            self.stop()
    
    def stop(self):
        """Stop the monitoring agent"""
        self.logger.info("Stopping ServerPulse Agent...")
        self.running = False
        self.stop_event.set()
        
        # Wait for threads to finish
        for thread in self.threads:
            thread.join(timeout=5)
        
        self.logger.info("ServerPulse Agent stopped")
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.stop()
    
    def _start_monitoring_threads(self):
        """Start background monitoring threads"""
        # Start crash detector thread
        crash_thread = threading.Thread(
            target=self.crash_detector.start_monitoring,
            args=(self.stop_event, self._on_crash_detected)
        )
        crash_thread.daemon = True
        crash_thread.start()
        self.threads.append(crash_thread)
        
        # Start log monitor thread
        log_thread = threading.Thread(
            target=self.log_monitor.start_monitoring,
            args=(self.stop_event, self._on_log_event)
        )
        log_thread.daemon = True
        log_thread.start()
        self.threads.append(log_thread)
        
        # Start service monitor thread
        service_thread = threading.Thread(
            target=self.service_monitor.start_monitoring,
            args=(self.stop_event, self._on_service_change)
        )
        service_thread.daemon = True
        service_thread.start()
        self.threads.append(service_thread)
    
    def _collect_and_send_metrics(self):
        """Collect system metrics and send to server"""
        try:
            # Collect system metrics
            metrics = self.system_collector.collect_all()
            
            # Add service status
            metrics['services'] = self.service_monitor.get_service_status()
            
            # Send to server
            self.api_client.send_metrics(metrics)
            
        except Exception as e:
            self.logger.error(f"Error collecting/sending metrics: {e}")
    
    def _send_heartbeat(self):
        """Send heartbeat to server"""
        try:
            self.api_client.send_heartbeat()
        except Exception as e:
            self.logger.error(f"Error sending heartbeat: {e}")
    
    def _on_crash_detected(self, crash_info):
        """Handle detected crashes"""
        self.logger.warning(f"Crash detected: {crash_info}")
        self.api_client.send_alert({
            'type': 'crash',
            'severity': 'critical',
            'message': f"System crash detected: {crash_info['cause']}",
            'details': crash_info,
            'timestamp': datetime.utcnow().isoformat()
        })
    
    def _on_service_change(self, service_name, old_status, new_status):
        """Handle service status changes"""
        self.logger.info(f"Service {service_name} changed from {old_status} to {new_status}")
        if new_status == 'failed':
            self.api_client.send_alert({
                'type': 'service_failure',
                'severity': 'high',
                'message': f"Service {service_name} has failed",
                'details': {'service': service_name, 'status': new_status},
                'timestamp': datetime.utcnow().isoformat()
            })
    
    def _on_log_event(self, event):
        """Handle log events"""
        if event.get('severity') in ['error', 'critical']:
            self.api_client.send_alert({
                'type': 'log_event',
                'severity': event.get('severity', 'medium'),
                'message': event.get('message'),
                'details': event,
                'timestamp': datetime.utcnow().isoformat()
            })


def main():
    """Main entry point"""
    # Check if running as root (recommended for system monitoring)
    if os.geteuid() != 0:
        print("Warning: Running as non-root user. Some metrics may not be available.")
    
    # Default config path
    config_path = "/etc/serverpulse-agent/config.yml"
    
    # Check for config file argument
    if len(sys.argv) > 1:
        config_path = sys.argv[1]
    
    # Create and start agent
    agent = ServerPulseAgent(config_path)
    
    try:
        agent.start()
    except KeyboardInterrupt:
        print("\nShutdown requested by user")
    except Exception as e:
        print(f"Fatal error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
