CREATE OR REPLACE FUNCTION register_user(
    p_first_name VARCHAR, -- Имя пользователя
    p_last_name VARCHAR, -- Фамилия пользователя
    p_middle_name VARCHAR, -- Отчество пользователя
    p_password VARCHAR, -- Пароль пользователя
    p_phone_number VARCHAR, -- Номер телефона пользователя
    p_email VARCHAR, -- Электронная почта пользователя
    p_role_name VARCHAR -- Название роли пользователя
)
RETURNS INTEGER AS $$
DECLARE
    new_user_id INTEGER; -- Идентификатор нового пользователя
    new_role_id INTEGER; -- Идентификатор роли пользователя
BEGIN
    -- Получение идентификатора роли на основе названия роли
    SELECT id INTO new_role_id FROM roles WHERE name ILIKE '%' || p_role_name || '%';

    -- Хеширование пароля
    p_password := crypt(p_password, gen_salt('bf'));

    -- Вставка нового пользователя с хешированным паролем
    INSERT INTO users (first_name, last_name, middle_name, password, phone_number, email, role)
    VALUES (p_first_name, p_last_name, p_middle_name, p_password, p_phone_number, p_email, new_role_id)
    RETURNING id INTO new_user_id;

    RETURN new_user_id; -- Возвращение идентификатора нового пользователя
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

