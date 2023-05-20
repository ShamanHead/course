<script>
    import {onMount} from 'svelte';
    import {register} from '../../api/register'

    let firstName = '';
    let middleName = '';
    let lastName = '';
    let phone = '';
    let email = '';
    let password = '';
    let errorMessage = '';

    const handleRegister = async () => {
        try {
            const response = await register(firstName, middleName, lastName, phone, email, password); // Call your login API function
            const {success, token} = response;
                console.log(firstName, middleName, lastName, phone, email, password);

            if (success) {
                localStorage.setItem('token', token);
                //window.location = 'http://localhost:5173/panel';
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
            // Redirect or perform any other actions if user is already logged in
        }
    });
</script>

<main class="min-h-screen flex items-center justify-center bg-gray-100">
    <div class="max-w-md w-full p-6 bg-white rounded-md shadow-md">
        <h2 class="text-2xl font-bold mb-6">Register</h2>
        {#if errorMessage}
        <p class="text-red-500 mb-4">{errorMessage}</p>
        {/if}
        <form class="space-y-4">
            <div>
                <label for="firstName" class="block mb-1">First Name</label>
                <input id="firstName" bind:value={firstName} class="w-full border-gray-300 rounded-md shadow-sm p-2" />
            </div>
            <div>
                <label for="lastName" class="block mb-1">Last Name</label>
                <input id="lastName" bind:value={lastName} class="w-full border-gray-300 rounded-md shadow-sm p-2" />
            </div>
            <div>
                <label for="middleName" class="block mb-1">Middle Name</label>
                <input id="middleName" bind:value={middleName}
                    class="w-full border-gray-300 rounded-md shadow-sm p-2" />
            </div>
            <div>
                <label for="phone" class="block mb-1">Phone number</label>
                <input id="phone" bind:value={phone}
                    class="w-full border-gray-300 rounded-md shadow-sm p-2" />
            </div>
            <div>
                <label for="password" class="block mb-1">Password</label>
                <input type="password" id="password" bind:value={password}
                    class="w-full border-gray-300 rounded-md shadow-sm p-2" />
            </div>
            <div>
                <label for="email" class="block mb-1">Email</label>
                <input id="email" bind:value={email} class="w-full border-gray-300 rounded-md shadow-sm p-2" />
            </div>
            <button type="button" class="w-full bg-blue-500 hover:bg-blue-600 text-white font-semibold py-2 rounded-md"
                on:click={handleRegister}>
                Register
            </button>
        </form>
    </div>
</main>
