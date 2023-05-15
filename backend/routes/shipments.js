var express = require('express');
var router = express.Router();

const db = require('../db');

router.post('/create', async function(req, res) {
    const { user_id, token, status, address, price, tax, weight, dimension } = req.body;

    try {
        let result = await db.func('add_shipment', [user_id, token, status, address, price, tax, weight, dimension])
        res.json({ success: true });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }
})

router.post('/list', async function(req, res) {
    const { user_id, token } = req.body;

    try {
        let result = await db.func('get_user_shipments', [user_id, token])
        res.json({ success: true, data: result });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }
})

router.patch('/update', async function(req, res) {
    const { user_id, token, shipment_id, status } = req.body;

    try {
        await db.func('update_shipment_status', [user_id, token, shipment_id, status])
        res.json({ success: true });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }
})

router.post('/bind', async function(req, res) {
    const { user_id, token, shipment_id, warehouse_id } = req.body;

    try {
        await db.func('bind_warehouse_to_shipment', [user_id, token, shipment_id, warehouse_id])
        res.json({ success: true });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }

})

module.exports = router;
