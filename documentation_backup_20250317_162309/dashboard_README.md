# Ephemery Checkpoint Sync Dashboard

A real-time monitoring and visualization dashboard for Ephemery node synchronization, with focus on checkpoint sync status and performance metrics.

## Features

- **Real-time Sync Status**: Monitor the sync status of both Lighthouse and Geth clients in real-time via WebSockets
- **Historical Data Visualization**: Track sync progress over time with interactive charts
- **Control Panel**: Restart clients, check checkpoint sync URLs, and run fix scripts directly from the dashboard
- **Performance Metrics**: View CPU, memory, and network usage during sync
- **REST API**: Access all sync data via a RESTful API
- **Mobile Responsive**: Optimized for desktop and mobile viewing

## Installation

The dashboard is automatically installed as part of the checkpoint sync fix implementation. To deploy it separately, use the dedicated playbook:

```bash
ansible-playbook -i inventory.yaml ansible/playbooks/deploy-dashboard.yaml
```

### Manual Installation

If you need to install the dashboard manually:

1. Install dependencies:
   ```bash
   pip install flask flask-cors websockets
   ```

2. Copy the files to the appropriate locations:
   ```bash
   mkdir -p /opt/ephemery/dashboard/api
   mkdir -p /opt/ephemery/dashboard/static/{css,js}
   mkdir -p /var/log/ephemery

   cp dashboard/api/* /opt/ephemery/dashboard/api/
   cp dashboard/static/* /opt/ephemery/dashboard/static/
   ```

3. Set up the systemd services:
   ```bash
   cp ansible/templates/dashboard-api.service.j2 /etc/systemd/system/dashboard-api.service
   cp ansible/templates/sync-websocket.service.j2 /etc/systemd/system/sync-websocket.service

   systemctl daemon-reload
   systemctl enable dashboard-api
   systemctl enable sync-websocket
   systemctl start dashboard-api
   systemctl start sync-websocket
   ```

4. Configure Nginx:
   ```bash
   cp ansible/templates/nginx-dashboard.conf.j2 /etc/nginx/sites-available/dashboard.conf
   ln -s /etc/nginx/sites-available/dashboard.conf /etc/nginx/sites-enabled/
   systemctl restart nginx
   ```

## Usage

### Accessing the Dashboard

Once installed, the dashboard can be accessed at:

```
http://YOUR_SERVER_IP/
```

### Dashboard Sections

1. **Client Status Cards**: Shows current sync status for Lighthouse and Geth
2. **Sync Progress Chart**: Displays sync progress over time
3. **Actions Panel**: Provides buttons for common operations
4. **Performance Metrics**: Shows resource usage during sync

### API Endpoints

The dashboard exposes several API endpoints:

- **GET /api/status**: Get current sync status for both clients
- **POST /api/restart/lighthouse**: Restart the Lighthouse client
- **GET /api/check-sync-urls**: Check available checkpoint sync URLs
- **POST /api/run-fix-script**: Run the fix_checkpoint_sync.sh script
- **GET /api/history**: Get historical sync data

### WebSocket Connection

For real-time updates, connect to the WebSocket server at:

```
ws://YOUR_SERVER_IP:5001
```

## Troubleshooting

### Services Not Starting

Check the logs for errors:

```bash
journalctl -u dashboard-api
journalctl -u sync-websocket
```

### Dashboard Not Loading

Verify Nginx is running and properly configured:

```bash
systemctl status nginx
nginx -t
```

### No Data Displayed

Check if the API server can reach the clients:

```bash
curl -s http://localhost:5052/eth/v1/node/syncing
curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8545
```

## Contributing

Contributions to the dashboard are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This dashboard is released under the same license as the Ephemery project.

## Acknowledgments

- The Ephemery team for their excellent work on the base project
- The checkpoint sync implementation team for creating the foundation for this dashboard
