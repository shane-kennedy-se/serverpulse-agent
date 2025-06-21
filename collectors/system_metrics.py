"""
System Metrics Collector
Collects CPU, memory, disk, network, and uptime metrics
"""

import psutil
import time
import platform
from datetime import datetime, timedelta


class SystemMetricsCollector:
    """Collects various system metrics using psutil"""
    
    def __init__(self, interval=30, logger=None):
        self.interval = interval
        self.logger = logger
        self.boot_time = psutil.boot_time()
    
    def collect_all(self):
        """Collect all system metrics"""
        try:
            metrics = {
                'timestamp': datetime.utcnow().isoformat(),
                'system_info': self.get_system_info(),
                'cpu': self.get_cpu_metrics(),
                'memory': self.get_memory_metrics(),
                'disk': self.get_disk_metrics(),
                'network': self.get_network_metrics(),
                'uptime': self.get_uptime(),
                'load_average': self.get_load_average(),
                'processes': self.get_top_processes()
            }
            
            if self.logger:
                self.logger.debug("System metrics collected successfully")
            
            return metrics
            
        except Exception as e:
            if self.logger:
                self.logger.error(f"Error collecting system metrics: {e}")
            return {}
    
    def get_system_info(self):
        """Get basic system information"""
        uname = platform.uname()
        return {
            'hostname': uname.node,
            'system': uname.system,
            'release': uname.release,
            'version': uname.version,
            'machine': uname.machine,
            'processor': uname.processor,
            'cpu_count': psutil.cpu_count(logical=True),
            'cpu_count_physical': psutil.cpu_count(logical=False)
        }
    
    def get_cpu_metrics(self):
        """Get CPU usage metrics"""
        # Get overall CPU usage
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # Get per-CPU usage
        cpu_percent_per_core = psutil.cpu_percent(interval=1, percpu=True)
        
        # Get CPU times
        cpu_times = psutil.cpu_times()
        
        # Get CPU frequency
        try:
            cpu_freq = psutil.cpu_freq()
            freq_info = {
                'current': cpu_freq.current,
                'min': cpu_freq.min,
                'max': cpu_freq.max
            } if cpu_freq else None
        except:
            freq_info = None
        
        return {
            'usage_percent': cpu_percent,
            'usage_per_core': cpu_percent_per_core,
            'times': {
                'user': cpu_times.user,
                'system': cpu_times.system,
                'idle': cpu_times.idle,
                'iowait': getattr(cpu_times, 'iowait', 0),
                'irq': getattr(cpu_times, 'irq', 0),
                'softirq': getattr(cpu_times, 'softirq', 0),
                'steal': getattr(cpu_times, 'steal', 0),
                'guest': getattr(cpu_times, 'guest', 0)
            },
            'frequency': freq_info
        }
    
    def get_memory_metrics(self):
        """Get memory usage metrics"""
        # Virtual memory
        vmem = psutil.virtual_memory()
        
        # Swap memory
        swap = psutil.swap_memory()
        
        return {
            'virtual': {
                'total': vmem.total,
                'available': vmem.available,
                'used': vmem.used,
                'free': vmem.free,
                'percent': vmem.percent,
                'buffers': getattr(vmem, 'buffers', 0),
                'cached': getattr(vmem, 'cached', 0),
                'shared': getattr(vmem, 'shared', 0)
            },
            'swap': {
                'total': swap.total,
                'used': swap.used,
                'free': swap.free,
                'percent': swap.percent,
                'sin': swap.sin,
                'sout': swap.sout
            }
        }
    
    def get_disk_metrics(self):
        """Get disk usage and I/O metrics"""
        disk_info = {}
        
        # Disk usage for each partition
        partitions = psutil.disk_partitions()
        for partition in partitions:
            try:
                usage = psutil.disk_usage(partition.mountpoint)
                disk_info[partition.mountpoint] = {
                    'device': partition.device,
                    'fstype': partition.fstype,
                    'total': usage.total,
                    'used': usage.used,
                    'free': usage.free,
                    'percent': usage.free / usage.total * 100 if usage.total > 0 else 0
                }
            except PermissionError:
                # This can happen on Windows or for system partitions
                continue
        
        # Disk I/O statistics
        try:
            disk_io = psutil.disk_io_counters()
            io_stats = {
                'read_count': disk_io.read_count,
                'write_count': disk_io.write_count,
                'read_bytes': disk_io.read_bytes,
                'write_bytes': disk_io.write_bytes,
                'read_time': disk_io.read_time,
                'write_time': disk_io.write_time
            } if disk_io else {}
        except:
            io_stats = {}
        
        return {
            'usage': disk_info,
            'io': io_stats
        }
    
    def get_network_metrics(self):
        """Get network interface metrics"""
        # Network I/O statistics
        net_io = psutil.net_io_counters(pernic=True)
        
        # Network connections
        try:
            connections = len(psutil.net_connections())
        except:
            connections = 0
        
        interfaces = {}
        for interface, stats in net_io.items():
            interfaces[interface] = {
                'bytes_sent': stats.bytes_sent,
                'bytes_recv': stats.bytes_recv,
                'packets_sent': stats.packets_sent,
                'packets_recv': stats.packets_recv,
                'errin': stats.errin,
                'errout': stats.errout,
                'dropin': stats.dropin,
                'dropout': stats.dropout
            }
        
        return {
            'interfaces': interfaces,
            'connections': connections
        }
    
    def get_uptime(self):
        """Get system uptime"""
        uptime_seconds = time.time() - self.boot_time
        uptime_delta = timedelta(seconds=uptime_seconds)
        
        return {
            'seconds': uptime_seconds,
            'boot_time': datetime.fromtimestamp(self.boot_time).isoformat(),
            'uptime_string': str(uptime_delta)
        }
    
    def get_load_average(self):
        """Get system load average (Linux/Unix only)"""
        try:
            load1, load5, load15 = psutil.getloadavg()
            return {
                '1min': load1,
                '5min': load5,
                '15min': load15
            }
        except AttributeError:
            # getloadavg() is not available on Windows
            return {}
    
    def get_top_processes(self, limit=10):
        """Get top processes by CPU and memory usage"""
        processes = []
        
        try:
            for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent', 'status']):
                try:
                    proc_info = proc.info
                    if proc_info['cpu_percent'] is None:
                        proc_info['cpu_percent'] = 0.0
                    if proc_info['memory_percent'] is None:
                        proc_info['memory_percent'] = 0.0
                    processes.append(proc_info)
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
            
            # Sort by CPU usage and get top processes
            top_cpu = sorted(processes, key=lambda x: x['cpu_percent'], reverse=True)[:limit]
            
            # Sort by memory usage and get top processes
            top_memory = sorted(processes, key=lambda x: x['memory_percent'], reverse=True)[:limit]
            
            return {
                'by_cpu': top_cpu,
                'by_memory': top_memory,
                'total_count': len(processes)
            }
            
        except Exception as e:
            if self.logger:
                self.logger.error(f"Error getting process information: {e}")
            return {'by_cpu': [], 'by_memory': [], 'total_count': 0}
