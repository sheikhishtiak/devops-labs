#!/bin/bash
set -e
# Setup — install a tool to work with
sudo apt update && sudo apt install -y nginx
sudo systemctl start nginx

# Exercise 1: Find nginx
ps aux | grep "[n]ginx"
# Write down the PID of the master process

# Exercise 2: Use systemctl to verify status
sudo systemctl status nginx

# Exercise 3: Reload nginx config without restarting
sudo systemctl reload nginx
# Verify it's still running (PID should be the same)
sudo systemctl status nginx

# Exercise 4: Stop nginx with kill (not systemctl)
# Get the master PID from ps aux
NGINX_PID=$(ps aux | grep "[n]ginx: master" | awk '{print $2}')
echo "Nginx master PID: $NGINX_PID"
sudo kill -SIGTERM $NGINX_PID
sleep 2
# Verify it stopped
ps aux | grep "[n]ginx" || echo "nginx stopped"
sudo systemctl status nginx || true

# Exercise 5: Restart it via systemctl
sudo systemctl start nginx
sleep 1
# Exercise 6: Check what port nginx is listening on
sudo ss -tlnp | grep nginx
# or
#sudo netstat -tlnp | grep nginx
