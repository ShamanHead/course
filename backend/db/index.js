const pgp = require('pg-promise')();
const connectionString = 'postgres://root:3313@postgres:5432/course';
const db = pgp(connectionString);

module.exports = db;
