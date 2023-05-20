<script>
    import {onMount} from 'svelte';
    import {login} from '../../api/login'

    let email = '';
    let password = '';
    let errorMessage = '';

    const handleLogin = async () => {
        try {
            const response = await login(email, password); // Call your login API function
            const {success, token} = response;
            if (success) {
                localStorage.setItem('token', token); // Save the session token to localStorage
                localStorage.setItem('user_id', success); // Save the session token to localStorage
                // Redirect or perform any other actions upon successful login
                window.location = 'http://localhost:5173/panel'
            } else {
                errorMessage = 'Invalid credentials. Please try again.'; // Display error message
            }
        } catch (error) {
            console.error(error);
            errorMessage = 'An error occurred. Please try again later.'; // Display generic error message
        }
    };

    onMount(() => {
        // Check if user is already logged in and perform any necessary actions
        const token = localStorage.getItem('token');
        if (token) {

        }
    });
</script>

<main class="min-h-screen flex items-center justify-center bg-gray-100">
    <div class="max-w-md w-full p-6 bg-white rounded-md shadow-md">
        <h2 class="text-2xl font-bold mb-6">Login</h2>
        {#if errorMessage}
        <p class="text-red-500 mb-4">{errorMessage}</p>
        {/if}
        <form class="space-y-4">
            <div>
                <label for="email" class="block mb-1">Email</label>
                <input type="email" id="email" bind:value={email}
                    class="w-full border-gray-300 rounded-md shadow-sm p-2" />
            </div>
            <div>
                <label for="password" class="block mb-1">Password</label>
                <input type="password" id="password" bind:value={password}
                    class="w-full border-gray-300 rounded-md shadow-sm p-2" />
            </div>
            <button type="button" class="w-full bg-blue-500 hover:bg-blue-600 text-white font-semibold py-2 rounded-md"
                on:click={handleLogin}>
                Log In
            </button>
        </form>
    </div>
</main>
