import { sql } from '../db.js';
import { getGroupAnalytics } from './analyticsService.js';
import { sendPushNotification } from './pushNotificationService.js';
import { v4 as uuidv4 } from 'uuid';

/**
 * Runs scheduled checks for reminders (You Owe, Someone Owes, Pending Settlement Approval)
 */
export async function runReminders() {
  console.log('⏰ Running scheduled reminders check...');
  try {
    // 1. Pending Settlement Approval (awaiting > 24 hours)
    const pendingSettlements = await sql`
      SELECT s.*, fu.name AS from_user_name, g.name AS group_name
      FROM settlements s
      JOIN users fu ON s.from_user = fu.id
      JOIN groups g ON s.group_id = g.id
      WHERE s.status = 'pending' AND s.created_at < NOW() - INTERVAL '24 hours'
    `;

    for (const s of pendingSettlements) {
      console.log(`⏰ Sending pending settlement reminder to user ${s.to_user}`);
      
      const notifId = uuidv4();
      // Insert in-app notification first
      await sql`
        INSERT INTO notifications (id, user_id, title, message, type, reference_id)
        VALUES (
          ${notifId},
          ${s.to_user},
          'Pending Settlement Approval',
          ${`Settlement of ₹${parseFloat(s.amount).toFixed(2)} from ${s.from_user_name} is awaiting your approval.`},
          'settlement_pending',
          ${s.group_id}
        )
      `;

      await sendPushNotification(s.to_user, {
        title: 'Pending Settlement Approval',
        body: `A settlement of ₹${parseFloat(s.amount).toFixed(2)} from ${s.from_user_name} in "${s.group_name}" has been pending for over 24 hours.`,
        data: {
          type: 'settlement_pending',
          groupId: s.group_id,
          referenceId: notifId
        }
      });
    }

    // 2. Outstanding Balances (You Owe / Someone Owes)
    // We check all non-locked groups
    const groups = await sql`
      SELECT g.id, g.name, g.created_at
      FROM groups g
      WHERE g.is_locked = FALSE
    `;

    for (const group of groups) {
      // Check if last expense in this group is older than 3 days
      const lastExpense = await sql`
        SELECT created_at FROM expenses 
        WHERE group_id = ${group.id} 
        ORDER BY created_at DESC LIMIT 1
      `;

      const referenceDate = lastExpense.length > 0 ? new Date(lastExpense[0].created_at) : new Date(group.created_at);
      const daysSinceLastActivity = (new Date() - referenceDate) / (1000 * 60 * 60 * 24);

      // Only remind if last activity was > 3 days ago (outstanding after period)
      if (daysSinceLastActivity >= 3) {
        const analytics = await getGroupAnalytics({ groupId: group.id });
        if (analytics && analytics.memberBalances) {
          for (const member of analytics.memberBalances) {
            if (member.netBalance < -1.00) { // Ower (owes more than 1 unit)
              console.log(`⏰ Sending "You Owe" reminder to user ${member.userId}`);
              
              const notifId = uuidv4();
              await sql`
                INSERT INTO notifications (id, user_id, title, message, type, reference_id)
                VALUES (
                  ${notifId},
                  ${member.userId},
                  'Outstanding Balance Reminder',
                  ${`You still owe ₹${Math.abs(member.netBalance).toFixed(2)} in "${group.name}".`},
                  'group_balance',
                  ${group.id}
                )
              `;

              await sendPushNotification(member.userId, {
                title: 'Outstanding Balance Reminder',
                body: `You still owe ₹${Math.abs(member.netBalance).toFixed(2)} in "${group.name}".`,
                data: {
                  type: 'group_balance',
                  groupId: group.id,
                  referenceId: notifId
                }
              });
            } else if (member.netBalance > 1.00) { // Creditor (owed more than 1 unit)
              console.log(`⏰ Sending "Someone Owes You" reminder to user ${member.userId}`);
              
              const notifId = uuidv4();
              await sql`
                INSERT INTO notifications (id, user_id, title, message, type, reference_id)
                VALUES (
                  ${notifId},
                  ${member.userId},
                  'Outstanding Balances Owed',
                  ${`Other members still owe you ₹${member.netBalance.toFixed(2)} in "${group.name}".`},
                  'group_balance',
                  ${group.id}
                )
              `;

              await sendPushNotification(member.userId, {
                title: 'Outstanding Balances Owed',
                body: `Other members still owe you ₹${member.netBalance.toFixed(2)} in "${group.name}".`,
                data: {
                  type: 'group_balance',
                  groupId: group.id,
                  referenceId: notifId
                }
              });
            }
          }
        }
      }
    }
    console.log('⏰ Scheduled reminders check completed successfully.');
  } catch (err) {
    console.error('❌ Error in scheduler:', err);
  }
}
