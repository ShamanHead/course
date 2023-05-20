var express = require('express');
var router = express.Router();

const db = require('../db');

router.post('/create', async function(req, res) {
    const { topic, description, user_id, status, token } = req.body;

    try {
        let result = await db.func('create_appeal', [topic, description, user_id, status, token])
        res.json({ success: true, data: result });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }
})

router.delete('/delete', async function(req, res) {
    const { appeal_id, user_id, token } = req.body;

    try {
        let result = await db.func('delete_appeal', [appeal_id, user_id, token])
        res.json({ success: true, data: result });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }
})

router.patch('/update', async function(req, res) {
    const { appeal_id, status, user_id, token } = req.body;

    try {
        await db.func('update_appeal_status', [appeal_id, status, user_id, token])
        res.json({ success: true });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }
})

router.post('/send', async function(req, res) {
    const { appeal_id, user_id, message, token } = req.body;

    try {
        await db.func('send_appeal_message', [appeal_id, user_id, message, token])
        res.json({ success: true });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }

})
router.post('/bind', async function(req, res) {
    const { appeal_id, support_id, token } = req.body;

    try {
        await db.func('bind_support', [appeal_id, support_id, token])
        res.json({ success: true });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }

})
module.exports = router;
