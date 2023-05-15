var express = require('express');
var router = express.Router();

const db = require('../db');

router.post('/create', async function(req, res) {
    const { number, user_id, token } = req.body;

    try {
        let result = await db.func('create_tracking', [number, user_id, token])
        res.json({ success: true });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }
})

router.delete('/delete', async function(req, res) {
    const { tracking_id, user_id, token } = req.body;

    try {
        let result = await db.func('delete_tracking', [tracking_id, user_id, token])
        res.json({ success: true });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }
})

router.post('/list', async function(req, res) {
    const { user_id, token } = req.body;

    try {
        let result = await db.func('get_trackings', [user_id, token])
        res.json({ success: true, data: result });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }
})

router.patch('/update', async function(req, res) {
    const { user_id, token, tracking_id, new_number } = req.body;

    try {
        await db.func('change_tracking_number', [tracking_id, new_number, user_id, token,])
        res.json({ success: true});
    } catch (exception) {
        res.status(500).json({ error: exception });
    }
})


module.exports = router;
