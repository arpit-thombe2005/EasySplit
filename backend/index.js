import 'dotenv/config';
import http from 'http';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { Server } from 'socket.io';

// Routes
import authRouter from './routes/auth.js';
import usersRouter from './routes/users.js';
import groupsRouter from './routes/groups.js';
import expensesRouter from './routes/expenses.js';
import settlementsRouter from './routes/settlements.js';
import notificationsRouter from './routes/notifications.js';
import invitationsRouter from './routes/invitations.js';
import configRouter from './routes/config.js';

const app = express();
const PORT = process.env.PORT || 3000;
const server = http.createServer(app);

// ── Socket.io Setup ───────────────────────────────────────────────
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

io.on('connection', (socket) => {
  console.log(`⚡ Socket connected: ${socket.id}`);

  socket.on('join_user', (userId) => {
    if (userId) {
      socket.join(`user_${userId}`);
      console.log(`👤 Socket ${socket.id} joined user room: user_${userId}`);
    }
  });

  socket.on('join_group', (groupId) => {
    if (groupId) {
      socket.join(`group_${groupId}`);
      console.log(`👥 Socket ${socket.id} joined group room: group_${groupId}`);
    }
  });

  socket.on('leave_group', (groupId) => {
    if (groupId) {
      socket.leave(`group_${groupId}`);
      console.log(`🚪 Socket ${socket.id} left group room: group_${groupId}`);
    }
  });

  socket.on('disconnect', () => {
    console.log(`🔌 Socket disconnected: ${socket.id}`);
  });
});

export function emitToGroup(groupId, event, data) {
  io.to(`group_${groupId}`).emit(event, data);
}

export function emitToUser(userId, event, data) {
  io.to(`user_${userId}`).emit(event, data);
}

export function broadcastRealtimeUpdate({ groupId, userIds, event, data }) {
  if (groupId) io.to(`group_${groupId}`).emit(event, data);
  if (userIds && Array.isArray(userIds)) {
    userIds.forEach(uid => io.to(`user_${uid}`).emit(event, data));
  }
}

// ── Security Middleware ───────────────────────────────────────────
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// ── Rate Limiting ─────────────────────────────────────────────────
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // strict limit for OTP endpoints
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests. Please try again later.' },
});

app.use('/api/auth', authLimiter);
app.use('/api', generalLimiter);

// ── Body Parsing ──────────────────────────────────────────────────
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// ── Health Check ──────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── API Routes ────────────────────────────────────────────────────
app.use('/api/auth', authRouter);
app.use('/api/users', usersRouter);
app.use('/api/groups', groupsRouter);
app.use('/api/expenses', expensesRouter);
app.use('/api/settlements', settlementsRouter);
app.use('/api/notifications', notificationsRouter);
app.use('/api/invitations', invitationsRouter);
app.use('/api/config', configRouter);


// ── 404 Handler ───────────────────────────────────────────────────
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// ── Global Error Handler ──────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  const statusCode = err.statusCode || 500;
  res.status(statusCode).json({
    error: err.message || 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});

// ── Start Server ──────────────────────────────────────────────────
server.listen(PORT, () => {
  console.log(`✅ EasySplit API with WebSockets running at http://localhost:${PORT}`);
  console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
});

export default app;
