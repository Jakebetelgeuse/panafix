const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

function sanitizeText(value, fallback = "") {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : fallback;
}

async function getUserRole(uid) {
  const userDoc = await db.collection("users").doc(uid).get();
  return userDoc.data()?.role || "client";
}

async function createNotification({
  userId,
  title,
  message,
  type,
  orderId = "",
  extraData = {},
}) {
  if (!userId) return;

  await db.collection("notifications").add({
    userId,
    title,
    message,
    type,
    orderId,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    ...extraData,
  });

  const userDoc = await db.collection("users").doc(userId).get();
  const token = sanitizeText(userDoc.data()?.fcmToken);

  if (!token) return;

  await messaging.send({
    token,
    notification: {
      title,
      body: message,
    },
    data: {
      orderId,
      type,
    },
  });
}

exports.reviewPayment = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesion.");
  }

  const role = await getUserRole(request.auth.uid);
  if (role !== "admin") {
    throw new HttpsError("permission-denied", "Solo admin puede revisar pagos.");
  }

  const orderId = sanitizeText(request.data?.orderId);
  const paymentStatus = sanitizeText(request.data?.paymentStatus);

  if (!orderId) {
    throw new HttpsError("invalid-argument", "Falta el id de la orden.");
  }

  if (!["paid", "rejected"].includes(paymentStatus)) {
    throw new HttpsError("invalid-argument", "Estado de pago invalido.");
  }

  const orderRef = db.collection("orders").doc(orderId);
  const orderSnap = await orderRef.get();

  if (!orderSnap.exists) {
    throw new HttpsError("not-found", "La orden no existe.");
  }

  const order = orderSnap.data() || {};
  const service = sanitizeText(order.service || order.serviceName, "Servicio");
  const clientId = sanitizeText(order.clientId);
  const technicianId = sanitizeText(order.technicianId);

  await orderRef.set({
    paymentStatus,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  if (paymentStatus === "paid") {
    await Promise.all([
      createNotification({
        userId: clientId,
        title: "Pago aprobado",
        message: `Tu pago del servicio "${service}" fue aprobado.`,
        type: "payment",
        orderId,
      }),
      createNotification({
        userId: technicianId,
        title: "Pago aprobado",
        message: `El pago del servicio "${service}" ya fue aprobado y puedes avanzar.`,
        type: "payment",
        orderId,
      }),
    ]);
  } else {
    await createNotification({
      userId: clientId,
      title: "Pago rechazado",
      message: `El pago del servicio "${service}" fue rechazado. Revisa el comprobante.`,
      type: "payment",
      orderId,
    });
  }

  return {
    ok: true,
    orderId,
    paymentStatus,
  };
});

exports.onOrderUpdated = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};
  const orderId = event.params.orderId;

  const previousStatus = sanitizeText(before.status);
  const nextStatus = sanitizeText(after.status);
  const previousPaymentStatus = sanitizeText(before.paymentStatus);
  const nextPaymentStatus = sanitizeText(after.paymentStatus);

  const service = sanitizeText(after.service || after.serviceName, "Servicio");
  const clientId = sanitizeText(after.clientId);
  const technicianId = sanitizeText(after.technicianId);

  const jobsMap = {
    accepted: {
      title: "Solicitud aceptada",
      message: `Tu servicio "${service}" fue aceptado por el tecnico.`,
    },
    on_the_way: {
      title: "Tecnico en camino",
      message: `El tecnico ya va en camino para "${service}".`,
    },
    arrived: {
      title: "Tecnico en el lugar",
      message: `El tecnico llego para atender "${service}".`,
    },
    working: {
      title: "Servicio en proceso",
      message: `Tu servicio "${service}" ya esta en ejecucion.`,
    },
    completed: {
      title: "Servicio completado",
      message: `El tecnico marco como completado el servicio "${service}".`,
    },
    cancelled: {
      title: "Servicio cancelado",
      message: `El servicio "${service}" fue cancelado.`,
    },
  };

  if (nextStatus && nextStatus !== previousStatus && jobsMap[nextStatus]) {
    await createNotification({
      userId: clientId,
      title: jobsMap[nextStatus].title,
      message: jobsMap[nextStatus].message,
      type: "job",
      orderId,
    });
  }

  if (nextPaymentStatus !== previousPaymentStatus && nextPaymentStatus === "released") {
    await createNotification({
      userId: technicianId,
      title: "Pago liberado",
      message: `El cliente libero el pago del servicio "${service}".`,
      type: "payment",
      orderId,
    });
  }
});

exports.onOrderMessageCreated = onDocumentCreated(
    "orders/{orderId}/messages/{messageId}",
    async (event) => {
      const message = event.data.data() || {};
      const orderId = event.params.orderId;
      const senderId = sanitizeText(message.senderId);
      const orderSnap = await db.collection("orders").doc(orderId).get();

      if (!orderSnap.exists) return;

      const order = orderSnap.data() || {};
      const clientId = sanitizeText(order.clientId);
      const technicianId = sanitizeText(order.technicianId);
      const receiverId = senderId === clientId ? technicianId : clientId;
      const senderName = sanitizeText(message.senderName, "Panafix");
      const text = sanitizeText(message.text, "Te enviaron un mensaje.");
      const service = sanitizeText(order.service || order.serviceName, "Servicio");

      if (!receiverId || receiverId === senderId) return;

      await createNotification({
        userId: receiverId,
        title: `Nuevo mensaje de ${senderName}`,
        message: `${service}: ${text}`,
        type: "chat",
        orderId,
      });
    },
);
