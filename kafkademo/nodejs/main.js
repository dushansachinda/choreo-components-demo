const { Kafka } = require('kafkajs');

// const kafka = new Kafka({
//   clientId: 'my-app',
//   brokers: ['2.tcp.ngrok.io:14890']
// });

const kafka = new Kafka({
    clientId: "order-consumer",
    brokers: ["pkc-6ojv2.us-west4.gcp.confluent.cloud:9092"],
    ssl: true,
    sasl: {
      mechanism: "plain",
      username: "22RAVPUCSTX365G5",
      password: "yQ5magtcSvzc5dT9aXNNcj6GevJ2zqYl7Bax7ECR+6q6FZR58dBvwohmeOiEeQcc",
    },
  });

const consumer = kafka.consumer({ groupId: 'order-consumers' });
const producer = kafka.producer();

const ordersTopic = 'orders';
const paymentSuccessOrdersTopic = 'payment-success-orders';

async function consumeOrders() {
  await consumer.connect();
  await consumer.subscribe({ topic: ordersTopic, fromBeginning: true });

  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      const order = JSON.parse(message.value.toString());

      if (order.paymentStatus === 'SUCCESS') {
        console.log(`Received a successful order: ${JSON.stringify(order)}`);

        await producePaymentSuccessOrder(order);
      }
    }
  });
}

async function producePaymentSuccessOrder(order) {
  await producer.connect();
  await producer.send({
    topic: paymentSuccessOrdersTopic,
    messages: [{ value: JSON.stringify(order) }]
  });
}

consumeOrders();
