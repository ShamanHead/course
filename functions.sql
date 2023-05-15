-- Создание функции для обновления строки в таблице "users"
CREATE OR REPLACE FUNCTION update_user(
    user_id INTEGER,
    first_name VARCHAR,
    last_name VARCHAR,
    middle_name VARCHAR,
    phone_number VARCHAR,
    email VARCHAR,
    role VARCHAR,
    unp VARCHAR
)
RETURNS VOID AS $$
BEGIN
    UPDATE users
    SET
        first_name = COALESCE(first_name, users.first_name),
        last_name = COALESCE(last_name, users.last_name),
        middle_name = COALESCE(middle_name, users.middle_name),
        phone_number = COALESCE(phone_number, users.phone_number),
        email = COALESCE(email, users.email),
        role = COALESCE(role, users.role),
        unp = COALESCE(unp, users.unp)
    WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;

-- Создание функции для удаления строки из таблицы "users"
CREATE OR REPLACE FUNCTION delete_user(user_id INTEGER)
RETURNS VOID AS $$
BEGIN
    DELETE FROM users WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;
