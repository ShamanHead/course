var express = require('express');
var router = express.Router();

const db = require('../db');

router.post('/register', async function(req, res) {
    // const { first_name, last_name, middle_name, email, password, phone_number } = req.body;

    try {
        // let result = await db.func('register_user', [first_name, last_name, middle_name, password, phone_number, email, 'Пользователь'])
        res.json([req.body]);
    } catch (exception) {
        res.status(500).json({ error: exception });
    }
})

router.post('/login', async function(req, res) {
    const { email, password } = req.body;

    try {
        let result = await db.func('login_user', [email, password])
        res.json({ success: true, token: result });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }
})

router.post('/logout', async function(req, res) {
    const { token } = req.body;

    try {
        let result = await db.func('logout_user', [token])
        res.json({ success: true, token: result[0].login_user });
    } catch (exception) {
        res.status(500).json({ error: exception });
    }
})

module.exports = router;
