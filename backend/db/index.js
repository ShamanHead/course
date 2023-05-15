const pgp = require('pg-promise')();
const connectionString = 'postgres://root:3313@localhost:5432/course';
const db = pgp(connectionString);

module.exports = db;
