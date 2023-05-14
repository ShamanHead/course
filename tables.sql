
CREATE TABLESPACE TS_USER LOCATION '/var/lib/postgresql/TS_USER';
CREATE TABLESPACE TS_SHIPMENTS LOCATION '/var/lib/postgresql/TS_SHIPMENTS';
CREATE TABLESPACE TS_TRACKINGS LOCATION '/var/lib/postgresql/TS_TRACKINGS';
CREATE TABLESPACE TS_APPEALS LOCATION '/var/lib/postgresql/TS_APPEALS';

drop tablespace TS_USER;
drop tablespace TS_SHIPMENTS;
drop tablespace TS_TRACKINGS;
drop tablespace TS_APPEALS;

CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(16) not NULL
);

insert into roles (name) values ('Пользователь');
insert into roles (name) values ('Тех. поддержка');
insert into roles (name) values ('Курьер');
insert into roles (name) values ('Оператор склада');
insert into roles (name) values ('Администратор');

-- Создание таблицы "warehouses"
CREATE TABLE warehouses (
    id SERIAL PRIMARY KEY,
    address VARCHAR(255) not NULL
);

insert into warehouses (address) values ('Ул. Казимира 5');
insert into warehouses (address) values ('Ул. Корженевского 21');
insert into warehouses (address) values ('Ул. Карла Маркса 10');
insert into warehouses (address) values ('Ул. Якуба Коласа 3');
insert into warehouses (address) values ('Ул. Сурганова 50');

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(60),
    last_name VARCHAR(60),
    middle_name VARCHAR(60),
    password VARCHAR(60),
    phone_number VARCHAR(18),
    email VARCHAR(255),
    role INT REFERENCES roles(id)
) tablespace TS_USER;

create unique index users_email on users(email);
create unique index users_phone on users(phone_number);

CREATE TABLE sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER references users(id),
    token VARCHAR(255),
	created_at DATE
);

create index sessions_userid on sessions(user_id);

-- Создание таблицы "appeals"
CREATE TABLE appeals (
    id SERIAL PRIMARY KEY,
    topic VARCHAR(255),
    description TEXT,
    status VARCHAR(255),
    user_id INT REFERENCES users(id),
    support_id INT REFERENCES users(id) NULL
) tablespace TS_APPEALS;

create index appeals_id on appeals(user_id, support_id);

create table appeals_messages (
	id serial primary key,
	appeal_id INT references appeals(id),
	user_id INT references users(id),
	message text
);

create index appeals_ids on appeals_messages(user_id, appeal_id);

-- Создание таблицы "shipments"
CREATE TABLE shipments (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    status VARCHAR(10),
    warehouse_id INT REFERENCES warehouses(id) NULL,
    address VARCHAR(100),
    price DECIMAL(8,3), 
    tax DECIMAL(8,3),
    weight DECIMAL,
    dimension VARCHAR(255),
    created_at DATE,
    updated_at DATE NULL
) tablespace TS_SHIPMENTS;

create index shipments_user_id on shipments(user_id);

-- Создание таблицы "trackings"
CREATE TABLE trackings (
    id SERIAL PRIMARY KEY,
    number VARCHAR(120),
    status VARCHAR(10),
    user_id INT REFERENCES users(id),
    created_at DATE,
    updated_at DATE NULL
) tablespace TS_TRACKINGS;

create unique index trackings_number on trackings(number);

CREATE VIEW user_shipment_view AS
SELECT u.id, u.first_name, u.last_name, u.middle_name, u.phone_number, u.email, u.role,
       COALESCE(SUM(s.tax), 0) AS total_tax,
       COALESCE(SUM(s.price), 0) AS total_price,
       COUNT(s.id) AS shipment_count
FROM users u
LEFT JOIN shipments s ON u.id = s.user_id
GROUP BY u.id, u.first_name, u.last_name, u.middle_name, u.phone_number, u.email, u.role;

select * from user_shipment_view

--

SET session_replication_role = 'replica';
SELECT 'DROP TABLE IF EXISTS "' || tablename || '" CASCADE;' 
FROM pg_tables
WHERE schemaname = 'public';

DROP TABLE IF EXISTS "appeals_messages" CASCADE;
DROP TABLE IF EXISTS "roles" CASCADE;
DROP TABLE IF EXISTS "users" CASCADE;
DROP TABLE IF EXISTS "user_role" CASCADE;
DROP TABLE IF EXISTS "sessions" CASCADE;
DROP TABLE IF EXISTS "appeals" CASCADE;
DROP TABLE IF EXISTS "shipments" CASCADE;
DROP TABLE IF EXISTS "warehouses" CASCADE;
DROP TABLE IF EXISTS "trackings" CASCADE;
drop view user_shipment_view;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Создание функции для регистрации пользователя
-- Функция регистрации пользователя
CREATE OR REPLACE FUNCTION register_user(
    p_first_name VARCHAR,
    p_last_name VARCHAR,
    p_middle_name VARCHAR,
    p_password VARCHAR,
    p_phone_number VARCHAR,
    p_email VARCHAR,
    p_role_name VARCHAR
)
RETURNS INTEGER AS $$
DECLARE
    new_user_id INTEGER;
    new_role_id INTEGER;
BEGIN
    -- Получаем идентификатор роли пользователя по имени роли
    SELECT id INTO new_role_id FROM roles WHERE name ILIKE '%' || p_role_name || '%';

    -- Хешируем пароль
    p_password := crypt(p_password, gen_salt('bf'));

    -- Вставляем нового пользователя с хешированным паролем
    INSERT INTO users (first_name, last_name, middle_name, password, phone_number, email, role)
    VALUES (p_first_name, p_last_name, p_middle_name, p_password, p_phone_number, p_email, new_role_id)
    RETURNING id INTO new_user_id;

    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql;

-- Функция входа пользователя
CREATE OR REPLACE FUNCTION login_user(p_email VARCHAR, p_password VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    user_id INTEGER;
    token VARCHAR;
BEGIN
    -- Проверяем соответствие электронной почты и хешированного пароля
    SELECT id INTO user_id FROM users WHERE email = p_email AND password = crypt(p_password, password);

    IF user_id IS NOT NULL THEN
        -- Генерируем новый токен сессии
        token := md5(random()::text || clock_timestamp()::text);

        -- Вставляем новую запись сессии с сгенерированным токеном
        INSERT INTO sessions (user_id, token, created_at)
        VALUES (user_id, token, current_date);

        -- Возвращаем идентификатор пользователя и токен сессии
        RETURN token;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Функция выхода пользователя
CREATE OR REPLACE FUNCTION logout_user(session VARCHAR)
RETURNS VOID AS $$
BEGIN
    -- Удаляем запись сессии по токену
    DELETE FROM sessions WHERE token = session;
END;
$$ LANGUAGE plpgsql;

-- Функция проверки действительности сессии
CREATE OR REPLACE FUNCTION check_session_valid(p_user_id INTEGER, p_token VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    is_valid BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
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

CREATE OR REPLACE FUNCTION check_user_role(p_user_id INTEGER, p_role_name VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    has_role BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM users u
        JOIN roles r ON u.role = r.id
        WHERE u.id = p_user_id AND r.name LIKE p_role_name
    ) INTO has_role;

    RETURN has_role;
END;
$$ LANGUAGE plpgsql;

select check_user_role(1, 'Администратор')

SELECT register_user('Арсений', 'Романовский', 'Владимирович', 'testpassword', '375293379834', 'ronyplay247@gmail.com', 'Пользователь');
SELECT register_user('Арсений', 'Романовский', 'Владимирович', 'testpassword', '3752933798342', 'ronyplay2473@gmail.com', 'Поддержка');
select login_user ('ronyplay247@gmail.com', 'testpassword')
select logout_user('08ae5df38fefe1edcb6782c6e3f800d3');

CREATE OR REPLACE FUNCTION add_shipment(
    p_user_id INTEGER,
    p_token VARCHAR(255),
    p_status VARCHAR(10),
    p_address VARCHAR(100),
    p_price DECIMAL(8,3),
    p_tax DECIMAL(8,3),
    p_weight DECIMAL,
    p_dimension VARCHAR(255)
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, добавляем новую отправку
    IF is_valid_session THEN
        INSERT INTO shipments (user_id, status, address, price, tax, weight, dimension, created_at)
        VALUES (p_user_id, p_status, p_address, p_price, p_tax, p_weight, p_dimension, current_date);
    ELSE
        -- Вызываем ошибку, если сессия недействительна
        RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bind_warehouse_to_shipment(
    p_user_id INTEGER,
    p_token VARCHAR(255),
    p_shipment_id INTEGER,
    p_warehouse_id INTEGER
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, выполняем привязку склада к отправке
    IF is_valid_session THEN
        -- Проверяем существование отправки
        IF NOT EXISTS (SELECT 1 FROM shipments WHERE id = p_shipment_id) THEN
            RAISE EXCEPTION 'Отправка с указанным идентификатором не существует';
        END IF;

        -- Проверяем существование склада
        IF NOT EXISTS (SELECT 1 FROM warehouses WHERE id = p_warehouse_id) THEN
            RAISE EXCEPTION 'Склад с указанным идентификатором не существует';
        END IF;

        -- Привязываем склад к отправке
        UPDATE shipments
        SET warehouse_id = p_warehouse_id
        WHERE id = p_shipment_id;
    ELSE
        -- Вызываем ошибку, если сессия недействительна
        RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_shipment_status(
    p_user_id INTEGER,
    p_token VARCHAR(255),
    p_shipment_id INTEGER
)
RETURNS VARCHAR AS $$
DECLARE
    is_valid_session BOOLEAN;
    shipment_status VARCHAR;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, получаем статус отправки
    IF is_valid_session THEN
        -- Получаем статус отправки
        SELECT status INTO shipment_status
        FROM shipments
        WHERE id = p_shipment_id;
        
        -- Если отправка существует, возвращаем ее статус
        IF FOUND THEN
            RETURN shipment_status;
        ELSE
            RAISE EXCEPTION 'Отправка с указанным идентификатором не существует';
        END IF;
    ELSE
        -- Вызываем ошибку, если сессия недействительна
        RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_user_shipments(p_user_id INTEGER, p_token VARCHAR(255))
RETURNS TABLE (
    shipment_id INTEGER,
    user_id INTEGER,
    status VARCHAR(10),
    address VARCHAR(100),
    price DECIMAL(8,3),
    tax DECIMAL(8,3),
    weight DECIMAL,
    dimension VARCHAR(255),
    created_at DATE,
    updated_at DATE
) AS $$
DECLARE
    is_valid_session BOOLEAN;
begin
	is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, получаем статус отправки
    IF is_valid_session THEN
    RETURN QUERY
    SELECT
        s.id AS shipment_id,
        s.user_id,
        s.status,
        s.address,
        s.price,
        s.tax,
        s.weight,
        s.dimension,
        s.created_at,
        s.updated_at
    FROM
        shipments s
    WHERE
        s.user_id = p_user_id;
    else 
    	raise exception 'Сессия недействительна';
    end if;
END;
$$ LANGUAGE plpgsql;

select add_shipment(
    1,
    '09c6a56cca6570095f8b30af9e53261c',
    'Принято',
    'Казимира 5',
    0,
    4,
    10,
    '10x10x10cm'
)

select get_user_shipments(
1, 
'09c6a56cca6570095f8b30af9e53261c'
)

select check_shipment_status(
    1,
    '09c6a56cca6570095f8b30af9e53261c',
    1
)

select bind_warehouse_to_shipment(
    1,
    '09c6a56cca6570095f8b30af9e53261c',
    1,
    1
)

CREATE OR REPLACE FUNCTION add_role(
    p_role_name VARCHAR,
    p_user_id INT,
    p_token VARCHAR
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
    is_admin BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Проверяем, является ли пользователь администратором
    SELECT EXISTS (
        SELECT 1
        FROM users
        WHERE role = (SELECT id FROM roles WHERE name = 'Администратор')
    ) INTO is_admin;

    -- Если сессия действительна и пользователь администратор, добавляем новую роль
    IF is_valid_session AND is_admin THEN
        -- Добавляем новую роль
        INSERT INTO roles (name)
        VALUES (p_role_name);
    ELSE
        -- Вызываем ошибку, если сессия недействительна или пользователь не является администратором
        RAISE EXCEPTION 'Недействительная сессия или отсутствует доступ к добавлению роли';
    END IF;
END;
$$ LANGUAGE plpgsql;

select add_role('Роль', 1, '09c6a56cca6570095f8b30af9e53261c');

CREATE OR REPLACE FUNCTION grant_role_to_user(
    p_user_id INTEGER,
    p_token VARCHAR(255),
    p_role_name VARCHAR
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
    user_role VARCHAR;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, проверяем роль пользователя
    IF is_valid_session THEN
        -- Получаем роль пользователя
        SELECT name INTO user_role FROM roles WHERE id = (select distinct role from users where id = p_user_id);

        -- Проверяем, является ли пользователь администратором
        IF user_role = 'Администратор' THEN
            -- Проверяем существование роли, которую необходимо назначить
            IF EXISTS (SELECT 1 FROM roles WHERE name ILIKE '%' || p_role_name || '%') THEN
                -- Назначаем роль пользователю
                UPDATE users SET role = (SELECT id FROM roles WHERE name ILIKE '%' || p_role_name || '%') WHERE id = p_user_id;
            ELSE
                -- Вызываем ошибку, если роль не существует
                RAISE EXCEPTION 'Указанная роль не существует';
            END IF;
        ELSE
            -- Вызываем ошибку, если пользователь не является администратором
            RAISE EXCEPTION 'Доступ запрещен. Только пользователь с ролью "Администратор" может назначать роли';
        END IF;
    ELSE
        -- Вызываем ошибку, если сессия недействительна
        RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT name INTO user_role FROM roles WHERE id = (select distinct role from users where id = 1);

select grant_role_to_user(1, '09c6a56cca6570095f8b30af9e53261c', 'Пользователь')

CREATE OR REPLACE FUNCTION create_appeal(
    p_topic VARCHAR(255),
    p_description TEXT,
    p_user_id INT,
    p_token VARCHAR(255)
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, добавляем новое обращение
    IF is_valid_session and check_user_role(p_user_id, 'Пользователь') THEN
        INSERT INTO appeals (topic, description, status, user_id)
        VALUES (p_topic, p_description, 'Новый', p_user_id);
    ELSE
        -- Вызываем ошибку, если сессия недействительна
		RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

select create_appeal('Деньги', )

CREATE OR REPLACE FUNCTION create_tracking(
    p_number VARCHAR(120),
    p_user_id INT,
    p_token VARCHAR(255)
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, добавляем новый трекинг
    IF is_valid_session THEN
        INSERT INTO trackings (number, status, user_id, created_at)
        VALUES (p_number, 'Статус', p_user_id, current_date);
    ELSE
        -- Вызываем ошибку, если сессия недействительна
        RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_tracking(
    p_tracking_id INTEGER,
    p_user_id INT,
    p_token VARCHAR(255)
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, удаляем трекинг
    IF is_valid_session THEN
        DELETE FROM trackings WHERE id = p_tracking_id;
    ELSE
        -- Вызываем ошибку, если сессия недействительна
        RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION change_tracking_number(
    p_tracking_id INTEGER,
    p_new_number VARCHAR(120),
    p_user_id INT,
    p_token VARCHAR(255)
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, меняем номер трекинга
    IF is_valid_session THEN
        UPDATE trackings SET number = p_new_number, updated_at = current_date
        WHERE id = p_tracking_id;
    ELSE
        -- Вызываем ошибку, если сессия недействительна
        RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

select create_tracking('fwefwefwef', 1, '44249689da70a4715fb45d51fa444ad1');
select change_tracking_number(1, 'test', 1, '44249689da70a4715fb45d51fa444ad1');
select delete_tracking(1, 1, '44249689da70a4715fb45d51fa444ad1');


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
$;
