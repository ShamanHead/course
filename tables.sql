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

create index appeals_id on appeals(user_id, support_id);

-- Создание таблицы "shipments"
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

-- Создание таблицы "trackings"
CREATE TABLE trackings (
    id SERIAL PRIMARY KEY,
    number VARCHAR(120),
    status VARCHAR(10),
    user_id INT REFERENCES users(id),
    created_at DATE,
    updated_at DATE NULL
);

create unique index trackings_number on trackings(number);

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
select login_user ('ronyplay247@gmail.com', 'testpassword')
select check_session_valid(2, '1ba3c632f5509382337dcf0d5f7267ec');
select logout_user('08ae5df38fefe1edcb6782c6e3f800d3');

-- Импорт данных в файл json.

COPY (SELECT row_to_json(Лоты) FROM Лоты) TO 'E:/file.json';


-- Импорт данных в xml.
CREATE OR REPLACE PROCEDURE export_database()
LANGUAGE plpgsql
AS $$
BEGIN
copy (SELECT database_to_xml(true, true, 'n')) to '/var/lib/postgresql/data/database.xml';
END;
$$;

CREATE OR REPLACE procedure import_xml_data(xml_content xml)
LANGUAGE plpgsql
as $$
BEGIN
  -- Insert data from the XML into the appropriate tables
  INSERT INTO users (id, first_name, last_name, middle_name, password, phone_number, email)
  SELECT
    (xpath('/course/public/users/id/text()', xml_content))[1]::text::integer,
    (xpath('/course/public/users/first_name/text()', xml_content))[1]::text,
    (xpath('/course/public/users/last_name/text()', xml_content))[1]::text,
    (xpath('/course/public/users/middle_name/text()', xml_content))[1]::text,
    (xpath('/course/public/users/password/text()', xml_content))[1]::text,
    (xpath('/course/public/users/phone_number/text()', xml_content))[1]::text,
    (xpath('/course/public/users/email/text()', xml_content))[1]::text;
END;
$$;

call generate_table_definitions_xml('public');
call export_database();

CREATE OR REPLACE FUNCTION MASS_INSERT_USERS()
RETURNS VOID AS $$
DECLARE
    I INTEGER := 1;
BEGIN
    WHILE I <= 100000 LOOP
        INSERT INTO GENRE (GENRE_NAME) VALUES ('GENRE ' || I);
        I := I + 1;
    END LOOP;
END;
$$ LANGUAGE PLPGSQL;

SELECT INSERT_GENRES();

