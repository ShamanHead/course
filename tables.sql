
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(16) not NULL
);

-- Создание таблицы "warehouses"
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
    role INT REFERENCES roles(id),
    unp VARCHAR(255)
);

CREATE TABLE sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER references users(id),
    token VARCHAR(255),
	created_at DATE
);

-- Создание таблицы "appeals"
CREATE TABLE appeals (
    id SERIAL PRIMARY KEY,
    appeal_type VARCHAR(255),
    topic VARCHAR(255),
    description TEXT,
    status VARCHAR(255),
    user_id INT REFERENCES users(id),
    support_id INT REFERENCES users(id)
);

-- Создание таблицы "shipments"
CREATE TABLE shipments (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    status VARCHAR(10),
    warehouse_id INT REFERENCES warehouses(id),
    price DECIMAL,
    weight DECIMAL,
    dimension VARCHAR(255),
    created_date DATE,
    updated_date DATE
);

-- Создание таблицы "trackings"
CREATE TABLE trackings (
    id SERIAL PRIMARY KEY,
    number VARCHAR(120),
    status VARCHAR(10),
    user_id INT REFERENCES users(id)
);

--

SET session_replication_role = 'replica';
SELECT 'DROP TABLE IF EXISTS "' || tablename || '" CASCADE;' 
FROM pg_tables
WHERE schemaname = 'public';

DROP TABLE IF EXISTS "roles" CASCADE;
DROP TABLE IF EXISTS "users" CASCADE;
DROP TABLE IF EXISTS "appeals" CASCADE;
DROP TABLE IF EXISTS "shipments" CASCADE;
DROP TABLE IF EXISTS "warehouses" CASCADE;
DROP TABLE IF EXISTS "trackings" CASCADE;
DROP TABLE IF EXISTS "sessions" CASCADE;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Создание функции для регистрации пользователя
CREATE OR REPLACE FUNCTION register_user(
    p_first_name VARCHAR,
    p_last_name VARCHAR,
    p_middle_name VARCHAR,
    p_password VARCHAR,
    p_phone_number VARCHAR,
    p_email VARCHAR,
    p_role_name VARCHAR,
    p_unp VARCHAR DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    new_user_id INTEGER;
    new_role_id INTEGER;
BEGIN
    SELECT id INTO new_role_id FROM roles WHERE name ILIKE '%' || p_role_name || '%';

    -- Hash the password
    p_password := crypt(p_password, gen_salt('bf'));

    -- Insert the new user with the hashed password
    INSERT INTO users (first_name, last_name, middle_name, password, phone_number, email, role, unp)
    VALUES (p_first_name, p_last_name, p_middle_name, p_password, p_phone_number, p_email, new_role_id, p_unp)
    RETURNING id INTO new_user_id;

    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql;

drop function login_user;

CREATE OR REPLACE FUNCTION login_user(p_email VARCHAR, p_password VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    user_id INTEGER;
    token VARCHAR;
BEGIN
    -- Check if the email and hashed password match
    SELECT id INTO user_id FROM users WHERE email = p_email AND password = crypt(p_password, password);

    IF user_id IS NOT NULL THEN
        -- Generate a new session token
        token := md5(random()::text || clock_timestamp()::text);

        -- Insert a new session record with the generated token
        INSERT INTO sessions (user_id, token, created_at)
        VALUES (user_id, token, current_date);

        -- Return the user ID and session token
        RETURN token;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION logout_user(session VARCHAR)
RETURNS VOID AS $$
BEGIN
    DELETE FROM sessions WHERE token = session;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_session_valid(p_user_id INTEGER, p_token VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    is_valid BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM sessions
        WHERE user_id = p_user_id
          AND token = p_token
          AND created_at = current_date
    ) INTO is_valid;

    RETURN is_valid;
END;
$$ LANGUAGE plpgsql;

SELECT register_user('Арсений', 'Романовский', 'Владимирович', 'testpassword', '375293379834', 'ronyplay247@gmail.com', 'Пользователь');
select login_user ('ronyplay247@gmail.com', 'testpassword') --1ba3c632f5509382337dcf0d5f7267ec
select check_session_valid(2, '1ba3c632f5509382337dcf0d5f7267ec');
select logout_user('08ae5df38fefe1edcb6782c6e3f800d3');

