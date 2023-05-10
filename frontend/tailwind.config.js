/** @type {import('tailwindcss').Config} */
module.exports = {
    content: [
        "./src/**/*.{html,js,svelte,ts}",
    ],
    theme: {
        extend: {
            screens: {
                'md-max': { 'max': '768px' }
            }
        },
    },
    plugins: [
    ],
}
