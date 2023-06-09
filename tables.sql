

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
CREATE EXTENSION IF NOT exists adminpack;

CREATE OR REPLACE FUNCTION remove_old_sessions()
RETURNS TRIGGER AS $$
BEGIN
    -- Удаление всех старых сеансов, кроме текущего для пользователя
    DELETE FROM sessions
    WHERE user_id = NEW.user_id
      AND token != NEW.token;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER remove_old_sessions_trigger
AFTER INSERT ON sessions
FOR EACH ROW
EXECUTE FUNCTION remove_old_sessions();
select * from register_user('Не арсений','Romanovskiy','Vladimirovich','rone@emf.c','2336077303','Пользователь')
SELECT register_user('Арсений', 'Романовский', 'Владимирович', 'testpassword', '375293379834', 'ronyplay247@gmail.com', 'Администратор');
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
CREATE OR REPLACE FUNCTION login_user(p_email VARCHAR, p_password VARCHAR, OUT user_id INTEGER, OUT token VARCHAR)
AS $$
BEGIN
    -- Проверяем соответствие электронной почты и хешированного пароля
    SELECT id, md5(random()::text || clock_timestamp()::text)
    INTO user_id, token
    FROM users
    WHERE email = p_email AND password = crypt(p_password, password);

    IF user_id IS NOT NULL THEN
        -- Вставляем новую запись сессии с сгенерированным токеном
        INSERT INTO sessions (user_id, token, created_at)
        VALUES (user_id, token, current_date);
    END IF;
END;
$$ LANGUAGE plpgsql;
drop function login_user;
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

SELECT register_user('Арсений', 'Романовский', 'Владимирович', 'testpassword', '375293379834', 'ronyplay247@gmail.com', 'Администратор');
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
    is_valid_session := check_session_valid(p_user_id, zp_token);

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

CREATE OR REPLACE FUNCTION update_shipment_status(
    p_user_id INTEGER,
    p_token VARCHAR(255),
    p_shipment_id INTEGER,
    p_status VARCHAR(10)
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Check if the session is valid
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- If the session is valid, update the shipment status
    IF is_valid_session THEN
        UPDATE shipments
        SET status = p_status
        WHERE id = p_shipment_id;
    ELSE
        -- Raise an exception if the session is invalid
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

CREATE OR REPLACE FUNCTION update_shipment_status(
    p_user_id INTEGER,
    p_token VARCHAR(255),
    p_shipment_id INTEGER,
    p_status VARCHAR(100)
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, обновляем статус отправки
    IF is_valid_session THEN
        -- Обновляем статус отправки
        UPDATE shipments
        SET status = p_status,
            updated_at = current_date
        WHERE id = p_shipment_id;
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
    wirehouse_id INT,
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
        s.warehouse_id,
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

drop function get_user_shipments;

DO $$
DECLARE
    function_name record;
BEGIN
    FOR function_name IN (
        SELECT routine_name, routine_schema
        FROM information_schema.routines
        WHERE routine_name = 'g'
    )
    LOOP
        EXECUTE 'DROP FUNCTION ' || quote_ident(function_name.routine_schema) || '.' || quote_ident(function_name.routine_name);
    END LOOP;
END$$;

select add_shipment(
    2,
    'c6680b36a25f9f4113caab8f3a815bd6',
    'Принято',
    'Казимира 5',
    0,
    4,
    10,
    '10x10x10cm'
)
select * from add_shipment(2,'8f88ede32fd982c92b3e3a1e08a9d25c','Init.','Ул. Мира, 28',0,3,100,'100x3x10')
select update_shipment_status(
    2,
   	'c6680b36a25f9f4113caab8f3a815bd6',
    1,
    'Поступило'
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

CREATE OR REPLACE FUNCTION get_trackings(p_user_id INTEGER, p_token VARCHAR(255))
RETURNS TABLE (
    tracking_id INTEGER,
    tracking_number VARCHAR(120),
    tracking_status VARCHAR(10),
    tracking_user_id INTEGER,
    tracking_created_at DATE,
    tracking_updated_at DATE
)
AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    is_valid_session := check_session_valid(p_user_id, p_token);

    IF is_valid_session THEN
        RETURN QUERY
        SELECT
            id AS tracking_id,
            number AS tracking_number,
            status AS tracking_status,
            user_id AS tracking_user_id,
            created_at AS tracking_created_at,
            updated_at AS tracking_updated_at
        FROM
            trackings
        WHERE
            trackings.user_id = p_user_id;
    ELSE
        RAISE EXCEPTION 'Invalid session';
    END IF;
END;
$$ LANGUAGE plpgsql;

drop function get_trackings;
select * from get_trackings(2,'8f88ede32fd982c92b3e3a1e08a9d25c')

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

call export_database();

CREATE OR REPLACE FUNCTION export_database(FILE_PATH TEXT)
RETURNS VOID AS
$$
DECLARE
  XML_DATA XML;
BEGIN
  SELECT XMLELEMENT(NAME "USERS", XMLAGG(XMLELEMENT(NAME "USER", 
    XMLFOREST(first_name, last_name, middle_name, password, phone_number, email, role)))) INTO XML_DATA FROM users;

  XML_DATA := '<?xml version="1.0" encoding="UTF-8"?>' || XML_DATA::TEXT;

  PERFORM PG_FILE_WRITE(FILE_PATH, XML_DATA::TEXT,'TRUE');
END;
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION import_xml(FILE_PATH TEXT)
RETURNS TABLE (
	first_name varchar(60),
	last_name varchar(60),
	middle_name varchar(60),
	"password" varchar(60),
	phone_number varchar(18),
	email varchar(255),
	"role" int4
) AS $$
DECLARE
    XML_DATA XML;
    USER_DATA RECORD;
BEGIN
 DROP TABLE IF EXISTS TEMP_USERS;
    CREATE TEMP TABLE TEMP_USERS (
		first_name varchar(60),
		last_name varchar(60),
		middle_name varchar(60),
		"password" varchar(60),
		phone_number varchar(18),
		email varchar(255),
		"role" int4
    );
    
    XML_DATA := XMLPARSE(DOCUMENT CONVERT_FROM(PG_READ_BINARY_FILE(FILE_PATH), 'UTF8'));
    
    FOR USER_DATA IN SELECT * FROM XMLTABLE('/USERS/USER' PASSING XML_DATA columns
        first_name varchar(60) path 'first_name',
		last_name varchar(60) path 'last_name',
		middle_name varchar(60) path 'middle_name',
		password varchar(60) path 'password',
		phone_number varchar(18) path 'phone_number',
		email varchar(255) path 'email',
		role int4 path 'role'
    ) LOOP
        INSERT INTO TEMP_USERS ( first_name, last_name, middle_name, password, phone_number, email, role)
        VALUES (
            USER_DATA.first_name,
            USER_DATA.last_name,
            USER_DATA.middle_name,
            USER_DATA.password,
            USER_DATA.phone_number,
            USER_DATA.email, 
            USER_DATA.role
        );
    END LOOP;

    RETURN QUERY SELECT * FROM TEMP_USERS;
END;
$$ LANGUAGE PLPGSQL;

select EXPORT_USERS_TO_XML_FILE('/var/lib/postgresql/data/database.xml');
select import_xml('/var/lib/postgresql/data/database.xml');

CREATE OR REPLACE FUNCTION create_appeal(
    p_topic VARCHAR(255),
    p_description TEXT,
    p_user_id INT,
    p_status VARCHAR(255),
    p_token VARCHAR(255)
)
RETURNS INT AS $$
DECLARE
    new_appeal_id INT;
    is_valid_session BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, создаем обращение
    IF is_valid_session THEN
        INSERT INTO appeals (topic, description, status, user_id)
        VALUES (p_topic, p_description, p_status, p_user_id)
        RETURNING id INTO new_appeal_id;

        RETURN new_appeal_id;
    ELSE
        -- Вызываем ошибку, если сессия недействительна
        RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_appeal_status(
    p_appeal_id INT,
    p_status VARCHAR(255),
    p_token VARCHAR(255)
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, обновляем статус обращения
    IF is_valid_session THEN
        UPDATE appeals
        SET status = p_status
        WHERE id = p_appeal_id;
    ELSE
        -- Вызываем ошибку, если сессия недействительна
        RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_appeal(
    p_appeal_id INT,
    p_token VARCHAR(255)
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, удаляем обращение
    IF is_valid_session THEN
        DELETE FROM appeals
        WHERE id = p_appeal_id;
    ELSE
        -- Вызываем ошибку, если сессия недействительна
        RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION send_appeal_message(
    p_appeal_id INT,
    p_user_id INT,
    p_message TEXT,
    p_token VARCHAR(255)
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- Если сессия действительна, отправляем сообщение
    IF is_valid_session THEN
        INSERT INTO appeals_messages (appeal_id, user_id, message)
        VALUES (p_appeal_id, p_user_id, p_message);
    ELSE
        -- Вызываем ошибку, если сессия недействительна
        RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_all_appeals(p_user_id INT, p_token VARCHAR(255))
RETURNS TABLE (
    appeal_id INT,
    topic VARCHAR(255),
    description TEXT,
    status VARCHAR(255),
    user_id INT,
    support_id INT
) AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Check if the session is valid
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- If the session is valid, retrieve all appeals
    IF is_valid_session THEN
        RETURN QUERY
        SELECT id AS appeal_id, topic, description, status, user_id, support_id
        FROM appeals;
    ELSE
        -- Raise an exception if the session is invalid
        RAISE EXCEPTION 'Invalid session';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_user_appeals(p_user_id INT, p_token VARCHAR(255))
RETURNS TABLE (
    appeal_id INT,
    topic VARCHAR(255),
    description TEXT,
    status VARCHAR(255),
    user_id INT,
    support_id INT
) AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Check if the session is valid
    is_valid_session := check_session_valid(p_user_id, p_token);

    -- If the session is valid, retrieve user-specific appeals
    IF is_valid_session THEN
        RETURN QUERY
        SELECT id AS appeal_id, topic, description, status, user_id, support_id
        FROM appeals
        WHERE user_id = p_user_id;
    ELSE
        -- Raise an exception if the session is invalid
        RAISE EXCEPTION 'Invalid session';
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT 'DROP FUNCTION ' || oid::regprocedure
FROM   pg_proc
WHERE  proname = 'create_appeal'  -- name without schema-qualification
AND    pg_function_is_visible(oid);  -- restrict to current search_path

DROP FUNCTION create_appeal(character varying,text,integer,character varying,character varying);
DROP FUNCTION create_appeal(character varying,character varying,text,integer,character varying)

CREATE ROLE ADMINISTRATOR_ROLE;
CREATE ROLE USER_ROLE;
CREATE ROLE SUPPORT_ROLE;
CREATE ROLE COURIER_ROLE;
CREATE ROLE OPERATOR_ROLE;

GRANT ALL PRIVILEGES ON DATABASE "course" TO ADMINISTRATOR_ROLE;

GRANT ALL ON TABLESPACE TS_USER TO ADMINISTRATOR_ROLE;
GRANT ALL ON TABLESPACE TS_SHIPMENTS TO ADMINISTRATOR_ROLE;
GRANT ALL ON TABLESPACE TS_TRACKINGS TO ADMINISTRATOR_ROLE;
GRANT ALL ON TABLESPACE TS_APPEALS TO ADMINISTRATOR_ROLE;

grant select, insert, update, delete on table trackings to USER_ROLE;
grant select, insert, update on table shipments to USER_ROLE;
grant select, insert on table appeals to USER_ROLE;
grant select, insert on table appeals_messages to USER_ROLE;
grant select on table warehouses to USER_ROLE;
grant select, insert on table sessions to USER_ROLE;

grant execute on function register_user to USER_ROLE;
grant execute on function login_user to USER_ROLE;
grant execute on function logout_user to USER_ROLE;
grant execute on function check_session_valid to USER_ROLE;
grant execute on function check_user_role to USER_ROLE;
grant execute on function add_shipment to USER_ROLE;
grant execute on function check_shipment_status to USER_ROLE;
grant execute on function get_user_shipments to USER_ROLE;
grant execute on function create_tracking to USER_ROLE;
grant execute on function delete_tracking to USER_ROLE;
grant execute on function change_tracking_number to USER_ROLE;
grant execute on function create_appeal to USER_ROLE;
grant execute on function delete_appeal to USER_ROLE;
grant execute on function send_appeal_message to USER_ROLE;
grant execute on function get_user_appeals to USER_ROLE;
grant execute on function update_appeal_status to USER_ROLE;

grant select, insert, update, delete on table appeals to SUPPORT_ROLE;
grant execute on function create_appeal to SUPPORT_ROLE;
grant execute on function delete_appeal to SUPPORT_ROLE;
grant execute on function send_appeal_message to SUPPORT_ROLE;
grant execute on function update_appeal_status to SUPPORT_ROLE;

grant select, update on table shipments to COURIER_ROLE;
grant select on table warehouses to COURIER_ROLE;
grant execute on function check_shipment_status to COURIER_ROLE;
grant execute on function update_shipment_status to COURIER_ROLE;

grant select, update on table shipments to OPERATOR_ROLE;
grant select on table warehouses to COURIER_ROLE;
grant execute on function bind_warehouse_to_shipment to COURIER_ROLE;
grant execute on function check_shipment_status to COURIER_ROLE;
grant execute on function update_shipment_status to COURIER_ROLE;

CREATE USER ADMIN_1 PASSWORD '123';
GRANT ADMINISTRATOR_ROLE TO ADMIN_1;

CREATE USER USER_1 WITH PASSWORD '123';
GRANT USER_ROLE TO USER_1;

CREATE USER SUPPORT_1 WITH PASSWORD '123';
GRANT SUPPORT_ROLE TO SUPPORT_1;

CREATE USER COURIER_1 WITH PASSWORD '123';
GRANT COURIER_ROLE TO COURIER_1;

CREATE USER OPERATOR_1 WITH PASSWORD '123';
GRANT OPERATOR_ROLE TO OPERATOR_1;

CREATE OR REPLACE FUNCTION INSERT_WAREHOUSES()
RETURNS VOID AS $$
DECLARE
    I INTEGER := 1;
BEGIN
    WHILE I <= 100000 LOOP
        INSERT INTO warehouses (address) VALUES ('WareHouse ' || I);
        I := I + 1;
    END LOOP;
END;
$$ LANGUAGE PLPGSQL;

select INSERT_WAREHOUSES()

-- Function to update user data
CREATE OR REPLACE FUNCTION update_user_data(
	p_admin_id INTEGER,
    p_token VARCHAR(255),
    p_user_id INTEGER,
    p_first_name VARCHAR,
    p_last_name VARCHAR,
    p_middle_name VARCHAR,
    p_phone_number VARCHAR,
    p_email VARCHAR
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(p_admin_id, p_token);

    -- Если сессия действительна, обновляем данные пользователя
    IF is_valid_session THEN
        -- Обновляем данные пользователя
        UPDATE users
        SET first_name = p_first_name,
            last_name = p_last_name,
            middle_name = p_middle_name,
            phone_number = p_phone_number,
            email = p_email
        WHERE id = p_user_id;
    ELSE
        -- Вызываем ошибку, если сессия недействительна
        RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to delete user
CREATE OR REPLACE FUNCTION delete_user(
    admin_user_id INTEGER,
    p_token VARCHAR(255),
    p_user_to_remove INTEGER
)
RETURNS VOID AS $$
DECLARE
    is_valid_session BOOLEAN;
BEGIN
    -- Проверяем, является ли сессия действительной
    is_valid_session := check_session_valid(admin_user_id, p_token);

    -- Если сессия действительна, удаляем пользователя
    IF is_valid_session then
    	delete from sessions where user_id = p_user_to_remove;
    	delete from trackings where user_id = p_user_to_remove;
    	delete from shipments where user_id = p_user_to_remove;
    	delete from appeals where user_id = p_user_to_remove;
    	delete from appeals_messages where user_id = p_user_to_remove;
    	-- Удаляем пользователя
        DELETE FROM users WHERE id = p_user_to_remove;
    ELSE
        -- Вызываем ошибку, если сессия недействительна
        RAISE EXCEPTION 'Недействительная сессия';
    END IF;
END;
$$ LANGUAGE plpgsql;

select delete_user(1, 'a04ba18fce8e354fd090abaca2562a81', 1);
select update_user_data(
	1,
    'a04ba18fce8e354fd090abaca2562a81',
    1,
    'Арсений',
    'Романовский',
    'Владимирович',
    '375293388888',
    'ronyplay247@gmail.com'
)

