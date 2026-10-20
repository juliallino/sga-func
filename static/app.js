(function () {
    if (window.sgaPortalInitialized) return;
    window.sgaPortalInitialized = true;
    var mobile = window.matchMedia('(max-width: 767px)');
    function setMenu(open) {
        var sidebar = document.querySelector('.portal-sidebar');
        var toggle = document.querySelector('.menu-toggle');
        var backdrop = document.querySelector('.menu-backdrop');
        if (!sidebar || !toggle) return;
        open = Boolean(open && mobile.matches);
        document.body.classList.toggle('portal-menu-open', open);
        toggle.setAttribute('aria-expanded', String(open));
        toggle.setAttribute('aria-label', open ? 'Fechar menu' : 'Abrir menu');
        sidebar.inert = mobile.matches && !open;
        if (backdrop) backdrop.hidden = !open;
    }
    function initialize() {
        document.body.classList.toggle('has-portal-menu', Boolean(document.querySelector('.portal-sidebar')));
        setMenu(false);
    }
    document.addEventListener('click', function (event) {
        if (event.target.closest('.menu-toggle')) {
            setMenu(!document.body.classList.contains('portal-menu-open'));
        } else if (event.target.closest('.menu-backdrop, .sidebar-link')) {
            setMenu(false);
        }
    });
    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && document.body.classList.contains('portal-menu-open')) {
            setMenu(false);
            var toggle = document.querySelector('.menu-toggle');
            if (toggle) toggle.focus();
        }
    });
    mobile.addEventListener('change', function () { setMenu(false); });
    document.addEventListener('DOMContentLoaded', initialize);
    document.addEventListener('turbolinks:load', initialize);
    document.addEventListener('turbolinks:before-cache', function () { setMenu(false); });
    if (document.readyState !== 'loading') initialize();
}());
