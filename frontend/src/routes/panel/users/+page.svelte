<script>

    let data = `
<thead>
        <tr>
            <th>User ID</th>
            <th>First Name</th>
            <th>Last Name</th>
            <th>Middle Name</th>
            <th>Password</th>
            <th>Phone Number</th>
            <th>Email</th>
            <th>Role</th>
        </tr>
    </thead>
`;

    function get() {
        try {
            // Close the database connection
            client.release();

            // Generate the HTML table
            let htmlTable = '<table>';
            htmlTable += '<tr><th>ID</th><th>First Name</th><th>Last Name</th><th>Middle Name</th><th>Password</th><th>Phone Number</th><th>Email</th><th>Role</th></tr>';

            result.rows.forEach(row => {
                htmlTable += '<tr>';
                htmlTable += `<td>${row.id}</td>`;
                htmlTable += `<td>${row.first_name}</td>`;
                htmlTable += `<td>${row.last_name}</td>`;
                htmlTable += `<td>${row.middle_name}</td>`;
                htmlTable += `<td>${row.password}</td>`;
                htmlTable += `<td>${row.phone_number}</td>`;
                htmlTable += `<td>${row.email}</td>`;
                htmlTable += `<td>${row.role}</td>`;
                htmlTable += '</tr>';
            });

            htmlTable += '</table>';

            // Log or use the generated HTML table
            console.log(htmlTable);

        } catch (error) {
            console.error('Error:', error);
        }
    }

    get();

</script>

<!-- <div class="modal-overlay"> -->
<!--     <div class="modal-content"> -->
<!--         <h2>Edit User</h2> -->
<!--         <form> -->
<!--             <div class="form-group"> -->
<!--                 <label for="first-name">First Name</label> -->
<!--                 <input type="text" id="first-name" class="form-input"> -->
<!--             </div> -->
<!--             <div class="form-group"> -->
<!--                 <label for="last-name">Last Name</label> -->
<!--                 <input type="text" id="last-name" class="form-input"> -->
<!--             </div> -->
<!--             <div class="form-group"> -->
<!--                 <label for="email">Middle Name</label> -->
<!--                 <input type="email" id="email" class="form-input"> -->
<!--             </div> -->
<!--             <div class="form-group"> -->
<!--                 <label for="email">Phone Number</label> -->
<!--                 <input type="email" id="email" class="form-input"> -->
<!--             </div> -->
<!--             <div class="form-group"> -->
<!--                 <label for="email">Role</label> -->
<!--                 <input type="email" id="email" class="form-input"> -->
<!--             </div> -->
<!--             <div class="form-group"> -->
<!--                 <label for="email">Email</label> -->
<!--                 <input type="email" id="email" class="form-input"> -->
<!--             </div> -->
<!--             <div class="form-group"> -->
<!--                 <label for="password">Password</label> -->
<!--                 <input type="password" id="password" class="form-input"> -->
<!--             </div> -->
<!--             <button type="submit" class="create-button">Create User</button> -->
<!--             <button type="submit" class="cancel-button">Cancel</button> -->
<!--         </form> -->
<!--     </div> -->
<!-- </div> -->


<table>
    {data}
    <tbody>
        <!-- Table rows with dynamic data -->
        <tr>
            <td>1</td>
            <td>John</td>
            <td>Doe</td>
            <td>Smith</td>
            <td>********</td>
            <td>1234567890</td>
            <td>johndoe@example.com</td>
            <td>Администратор</td>
        </tr>
        <tr>
            <td>2</td>
            <td>Jane</td>
            <td>Smith</td>
            <td>Johnson</td>
            <td>********</td>
            <td>9876543210</td>
            <td>janesmith@example.com</td>
            <td>Пользователь</td>
        </tr>
    </tbody>
</table>
