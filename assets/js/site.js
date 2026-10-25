/* Davy Jones Quality Meats — site behaviour.
   Everything here is progressive enhancement: the pages work without it. */
(function () {
  'use strict';

  /* ---------------------------------------------------------- Nav dropdowns */

  var groups = Array.prototype.slice.call(document.querySelectorAll('.nav__group'));

  // Grace period before a hover-out closes the menu, so clipping a corner on
  // the way down to an item doesn't shut it in your face.
  var CLOSE_DELAY = 220;

  groups.forEach(function (group) {
    var toggle = group.querySelector('.nav__toggle');
    var menu = group.querySelector('.nav__menu');
    if (!toggle || !menu) return;

    var timer = null;

    function open(state) {
      clearTimeout(timer);
      toggle.setAttribute('aria-expanded', String(state));
      menu.hidden = !state;
    }

    function closeSoon() {
      clearTimeout(timer);
      timer = setTimeout(function () { open(false); }, CLOSE_DELAY);
    }

    open(false);

    toggle.addEventListener('click', function (e) {
      e.stopPropagation();
      var isOpen = toggle.getAttribute('aria-expanded') === 'true';
      closeAll();
      open(!isOpen);
    });

    group.addEventListener('mouseenter', function () { open(true); });
    group.addEventListener('mouseleave', closeSoon);
    group.addEventListener('focusout', function () {
      if (!group.contains(document.activeElement)) open(false);
    });

    group._djClose = function () { open(false); };
  });

  function closeAll() {
    groups.forEach(function (g) { if (g._djClose) g._djClose(); });
  }

  document.addEventListener('click', closeAll);
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { closeAll(); closeDrawer(); }
  });

  /* ------------------------------------------------------------ Mobile menu */

  var burger = document.querySelector('.burger');
  var drawer = document.getElementById('drawer');
  var drawerClose = document.querySelector('.drawer__close');

  function openDrawer() {
    if (!drawer) return;
    drawer.hidden = false;
    document.documentElement.style.overflow = 'hidden';
    if (burger) burger.setAttribute('aria-expanded', 'true');
    if (drawerClose) drawerClose.focus();
  }
  function closeDrawer() {
    if (!drawer || drawer.hidden) return;
    drawer.hidden = true;
    document.documentElement.style.overflow = '';
    if (burger) { burger.setAttribute('aria-expanded', 'false'); burger.focus(); }
  }

  if (burger) burger.addEventListener('click', openDrawer);
  if (drawerClose) drawerClose.addEventListener('click', closeDrawer);

  /* ------------------------------------------------ Section jump-link state */

  var jumpnav = document.querySelector('.jumpnav');
  if (jumpnav && 'IntersectionObserver' in window) {
    var links = Array.prototype.slice.call(jumpnav.querySelectorAll('a[href^="#"]'));
    var targets = links
      .map(function (a) { return document.getElementById(a.getAttribute('href').slice(1)); })
      .filter(Boolean);

    if (targets.length) {
      var setActive = function (id) {
        links.forEach(function (a) {
          a.classList.toggle('is-active', a.getAttribute('href') === '#' + id);
        });
      };

      var observer = new IntersectionObserver(function (entries) {
        var visible = entries
          .filter(function (e) { return e.isIntersecting; })
          .sort(function (a, b) { return a.boundingClientRect.top - b.boundingClientRect.top; });
        if (visible.length) setActive(visible[0].target.id);
      }, { rootMargin: '-45% 0px -50% 0px', threshold: 0 });

      targets.forEach(function (t) { observer.observe(t); });
      setActive(targets[0].id);
    }
  }

  /* ------------------------------------------------------- Today's hours */
  /* Bolds the current day's row in the footer. Each row carries data-days,
     a comma-separated list of day numbers (0 = Sunday).                   */

  var today = new Date().getDay();
  Array.prototype.forEach.call(document.querySelectorAll('[data-days]'), function (el) {
    var days = el.getAttribute('data-days').split(',').map(Number);
    if (days.indexOf(today) !== -1) el.classList.add('is-today');
  });

  /* The site carries no forms. Loyalty sign-up happens on Marsello and the
     contact form was dropped, so the pending-submit handler that used to
     live here has gone with them. See docs/integrations.md.               */
})();
