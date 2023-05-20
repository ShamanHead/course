<nav class="navigation">
    <div class="logo">
        MegaPochta
    </div>
    <div class="routes">
        <a class="route" href="/login">Выйти</a>
    </div>
</nav>
<div class="content">
    <div class="panel">
        <div class="item">
            <a href="/panel/shipments">Отправления</a>
        </div>
        <div class="item">
            <a href="/panel/trackings">Отслеживания</a>
        </div>
        <div class="item">
            <a href="/panel/appeals">Поддержка</a>
        </div>
        <div class="item">
            <a href="/panel/users">Пользователи</a>
        </div>
        <div class="item">
            <a href="/panel/stats">Статистика</a>
        </div>
    </div>
    <div class="basic-panel-page">
        <slot></slot>
    </div>
</div>
