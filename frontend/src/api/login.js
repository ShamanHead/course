export const login = async (login, password) => {
    return await fetch("http://localhost:3000/users/login", {
        method: "POST",
        body: JSON.stringify({
            login: login,
            password: password
        })
    }).then(res => res.json())
}
