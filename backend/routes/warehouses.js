var express = require('express');
var router = express.Router();

const db = require('../db');

router.get('/list', async function(req, res) {
    /* try {
        await db.func('warehouses_list')
        res.json({ success: true });
    } catch (exception) {
        res.status(500).json({ error: exception });
    } */
})

module.exports = router;
