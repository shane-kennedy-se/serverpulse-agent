"""
Logging Setup
Configures logging for the ServerPulse agent
"""

import logging
import logging.handlers
import sys
from pathlib import Path


def setup_logger(level='INFO', log_file=None, max_size='10MB', backup_count=5):
    """Setup logging configuration for the agent"""
    
    # Create logger
    logger = logging.getLogger('serverpulse-agent')
    logger.setLevel(getattr(logging, level.upper(), logging.INFO))
    
    # Clear any existing handlers
    logger.handlers.clear()
    
    # Create formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # File handler (if specified)
    if log_file:
        try:
            # Create log directory if it doesn't exist
            log_path = Path(log_file)
            log_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Convert max_size to bytes
            if isinstance(max_size, str):
                size_bytes = parse_size(max_size)
            else:
                size_bytes = max_size
            
            # Create rotating file handler
            file_handler = logging.handlers.RotatingFileHandler(
                log_file,
                maxBytes=size_bytes,
                backupCount=backup_count
            )
            file_handler.setLevel(getattr(logging, level.upper(), logging.INFO))
            file_handler.setFormatter(formatter)
            logger.addHandler(file_handler)
            
        except Exception as e:
            logger.warning(f"Could not setup file logging: {e}")
    
    # Set logging level for external libraries
    logging.getLogger('requests').setLevel(logging.WARNING)
    logging.getLogger('urllib3').setLevel(logging.WARNING)
    
    return logger


def parse_size(size_str):
    """Parse size string like '10MB' to bytes"""
    size_str = size_str.upper().strip()
    
    if size_str.endswith('B'):
        size_str = size_str[:-1]
    
    multipliers = {
        'K': 1024,
        'M': 1024 * 1024,
        'G': 1024 * 1024 * 1024
    }
    
    for suffix, multiplier in multipliers.items():
        if size_str.endswith(suffix):
            return int(float(size_str[:-1]) * multiplier)
    
    # Default to bytes if no suffix
    try:
        return int(size_str)
    except ValueError:
        return 10 * 1024 * 1024  # Default 10MB


def get_logger(name=None):
    """Get a logger instance"""
    if name:
        return logging.getLogger(f'serverpulse-agent.{name}')
    return logging.getLogger('serverpulse-agent')
