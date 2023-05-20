export const register = async (firstName, middleName, lastName, phone, email, password) => {
    return await fetch("http://localhost:3000/users/register", {
        method: "POST",
        body: JSON.stringify({
            "first_name": firstName,
            "last_name": lastName,
            "middle_name": middleName,
            "email": email,
            "password": password,
            "phone_number": phone,
        })
    }).then(res => res.json())
}
