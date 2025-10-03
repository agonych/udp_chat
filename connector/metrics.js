/**
 * Prometheus metrics for UDPChat-AI Connector
 */

const client = require('prom-client');

// Create a Registry to register the metrics
const register = new client.Registry();

// Add a default label which is added to all metrics
register.setDefaultLabels({
  app: 'udpchat-connector'
});

// Enable the collection of default metrics
client.collectDefaultMetrics({ register });

// Custom metrics
const websocketConnections = new client.Gauge({
  name: 'udpchat_websocket_connections',
  help: 'Number of active WebSocket connections',
  registers: [register]
});

const websocketMessagesReceived = new client.Counter({
  name: 'udpchat_websocket_messages_received_total',
  help: 'Total number of WebSocket messages received',
  registers: [register]
});

const websocketMessagesSent = new client.Counter({
  name: 'udpchat_websocket_messages_sent_total',
  help: 'Total number of WebSocket messages sent',
  registers: [register]
});

const udpMessagesReceived = new client.Counter({
  name: 'udpchat_udp_messages_received_total',
  help: 'Total number of UDP messages received from server',
  registers: [register]
});

const udpMessagesSent = new client.Counter({
  name: 'udpchat_udp_messages_sent_total',
  help: 'Total number of UDP messages sent to server',
  registers: [register]
});

const messageProcessingTime = new client.Histogram({
  name: 'udpchat_message_processing_seconds',
  help: 'Time spent processing messages',
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [register]
});

// Register the custom metrics
register.registerMetric(websocketConnections);
register.registerMetric(websocketMessagesReceived);
register.registerMetric(websocketMessagesSent);
register.registerMetric(udpMessagesReceived);
register.registerMetric(udpMessagesSent);
register.registerMetric(messageProcessingTime);

module.exports = {
  register,
  websocketConnections,
  websocketMessagesReceived,
  websocketMessagesSent,
  udpMessagesReceived,
  udpMessagesSent,
  messageProcessingTime
};





