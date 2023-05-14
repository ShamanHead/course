CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(16) not NULL
);

CREATE TABLE warehouses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) not NULL,
    address VARCHAR(255) not NULL
);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(60),
    last_name VARCHAR(60),
    middle_name VARCHAR(60),
    password VARCHAR(60),
    phone_number VARCHAR(18),
    email VARCHAR(255),
    role INT REFERENCES roles(id)
);

create unique index users_email on users(email);
create unique index users_phone on users(phone_number);

CREATE TABLE sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER references users(id),
    token VARCHAR(255),
	created_at DATE
);

create unique index sessions_user_id on sessions(user_id);

CREATE TABLE appeals (
    id SERIAL PRIMARY KEY,
    appeal_type VARCHAR(255),
    topic VARCHAR(255),
    description TEXT,
    status VARCHAR(255),
    user_id INT REFERENCES users(id),
    support_id INT REFERENCES users(id)
);

create index appeals_id on appeals(user_id, support_id);

CREATE TABLE shipments (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    status VARCHAR(10),
    warehouse_id INT REFERENCES warehouses(id),
    price DECIMAL(8,3), 
    tax DECIMAL(8,3),
    weight DECIMAL,
    dimension VARCHAR(255),
    created_at DATE,
    updated_at DATE NULL
);

create index shipments_user_id on shipments(user_id);

CREATE TABLE trackings (
    id SERIAL PRIMARY KEY,
    number VARCHAR(120),
    status VARCHAR(10),
    user_id INT REFERENCES users(id),
    created_at DATE,
    updated_at DATE NULL
);

create unique index trackings_number on trackings(number);
