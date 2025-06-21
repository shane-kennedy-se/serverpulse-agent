#!/usr/bin/env python3
"""
Setup script for ServerPulse Agent
"""

from setuptools import setup, find_packages
from pathlib import Path

# Read the README file
readme_file = Path(__file__).parent / "README.md"
long_description = readme_file.read_text() if readme_file.exists() else ""

# Read requirements
requirements_file = Path(__file__).parent / "requirements.txt"
requirements = []
if requirements_file.exists():
    requirements = requirements_file.read_text().strip().split('\n')

setup(
    name="serverpulse-agent",
    version="1.0.0",
    description="Linux monitoring agent for ServerPulse server management",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="ServerPulse Team",
    author_email="support@serverpulse.com",
    url="https://github.com/yourusername/serverpulse-agent",
    packages=find_packages(),
    install_requires=requirements,
    python_requires=">=3.6",
    entry_points={
        'console_scripts': [
            'serverpulse-agent=serverpulse_agent:main',
            'serverpulse-cli=agent_cli:main',
        ],
    },
    data_files=[
        ('/etc/serverpulse-agent', ['config.yml.example']),
        ('/etc/systemd/system', ['serverpulse-agent.service']),
    ],
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: System Administrators",
        "License :: OSI Approved :: MIT License",
        "Operating System :: POSIX :: Linux",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Topic :: System :: Monitoring",
        "Topic :: System :: Systems Administration",
    ],
    keywords="monitoring linux server metrics systemd logs",
    project_urls={
        "Bug Reports": "https://github.com/yourusername/serverpulse-agent/issues",
        "Source": "https://github.com/yourusername/serverpulse-agent",
        "Documentation": "https://docs.serverpulse.com",
    },
)
