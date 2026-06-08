/* ============================================================================
 * MicroarrAI - Custom JavaScript
 * ============================================================================
 * Description: Scroll-based tile animation for Home page + ML Sidebar
 * Author: Sergio Olmos Piñero et al.
 * ============================================================================
 */

/**
 * METIS glass navbar -> Shiny tab switching (called from inline onclick).
 */
function metisNav(tab, el) {
  if (window.Shiny) Shiny.setInputValue('nav_target', tab, { priority: 'event' });
  document.querySelectorAll('.metis-link').forEach(function (l) { l.classList.remove('active'); });
  if (el) el.classList.add('active');
}

/**
 * Light/dark switcher. Themes the app navbar (body.metis-light) and forwards
 * the choice to the landing iframe via postMessage.
 */
function metisTheme(btn) {
  var light = document.body.classList.toggle('metis-light');
  if (btn) btn.innerHTML = light ? '☾' : '☀';  // ☾ / ☀
  var frame = document.querySelector('.metis-home__frame');
  if (frame && frame.contentWindow) {
    frame.contentWindow.postMessage({ type: 'metis-theme', light: light }, '*');
  }
}

/**
 * Scroll Event Handler for Animated Tiles
 * 
 * Updates tile colors based on scroll position through sections
 * Creates a layered visual effect that responds to user navigation
 */
document.addEventListener('scroll', function() {
  var sections = document.querySelectorAll('.section');
  var tiles = document.querySelectorAll('.tile');
  var scrollPosition = window.pageYOffset || document.documentElement.scrollTop;
  
  // Margin before activating the first layer
  var offsetMargin = 100;
  
  // If at the top, restore all tiles to gray
  if (scrollPosition <= offsetMargin) {
    tiles.forEach(function(tile, index) {
      tile.classList.add('tile-gray');
      tile.classList.remove('active-tile-' + (index + 1));
    });
    return;
  }
  
  // Update tiles based on section visibility
  sections.forEach(function(section, index) {
    if (section.offsetTop <= scrollPosition + window.innerHeight / 2 - offsetMargin) {
      section.classList.add('active');
      
      // Update corresponding tile color
      tiles.forEach(function(tile, i) {
        if (i === index) {
          tile.classList.add('active-tile-' + (index + 1));
          tile.classList.remove('tile-gray');
        } else if (i < index) {
          tile.classList.add('tile-gray');
          tile.classList.remove('active-tile-' + (i + 1));
        } else {
          tile.classList.remove('tile-gray');
          tile.classList.remove('active-tile-' + (i + 1));
        }
      });
    } else {
      section.classList.remove('active');
    }
  });
});

/**
 * Sidebar Management System
 * 
 * Handles floating sidebars for ML and Peptide dashboards
 */
$(document).ready(function() {
  
  // Auto-enable CV when RFE is checked (RFE requires CV to work)
  $(document).on('change', '#ml_use_rfe', function() {
    if ($(this).is(':checked')) {
      $('#ml_use_cv').prop('checked', true);
      // Trigger change event to update Shiny
      $('#ml_use_cv').trigger('change');
    }
  });
  
  // Custom easing function for smooth scrolling
  $.easing.easeInOutCubic = function(x, t, b, c, d) {
    if ((t /= d / 2) < 1) return c / 2 * t * t * t + b;
    return c / 2 * ((t -= 2) * t * t + 2) + b;
  };
  
  // ===== ML SIDEBAR =====
  var mlSidebarOpen = false;
  
  // ML Sidebar Toggle
  $(document).on('click', '#ml-sidebar-toggle', function() {
    mlSidebarOpen = !mlSidebarOpen;
    
    if (mlSidebarOpen) {
      $('#ml-sidebar').addClass('open').css('left', '0');
      $('.ml-content').css('margin-left', '320px');
      $(this).addClass('sidebar-open');
      $(this).html('<i class="fa fa-times"></i>');
    } else {
      $('#ml-sidebar').removeClass('open').css('left', '-320px');
      $('.ml-content').css('margin-left', '0');
      $(this).removeClass('sidebar-open');
      $(this).html('<i class="fa fa-bars"></i>');
    }
  });
  
  // ML Sidebar Navigation
  $(document).on('click', '.ml-sidebar-item', function() {
    var targetSection = $(this).data('target');
    
    // Update active state
    $('.ml-sidebar-item').removeClass('active');
    $(this).addClass('active');
    
    // Scroll to the section if it exists
    var targetElement = $('#' + targetSection);
    if (targetElement.length > 0) {
      $('html, body').stop().animate({
        scrollTop: targetElement.offset().top - 100
      }, 200, 'easeInOutCubic');
    }
    
    // Send to Shiny
    Shiny.setInputValue('ml_nav_section', targetSection, {priority: "event"});
  });
  
  // ===== PEPTIDE SIDEBAR =====
  var peptideSidebarOpen = false;
  
  // Peptide Sidebar Toggle
  $(document).on('click', '#peptide-sidebar-toggle', function() {
    peptideSidebarOpen = !peptideSidebarOpen;
    
    if (peptideSidebarOpen) {
      $('#peptide-sidebar').addClass('open').css('left', '0');
      $('.ml-content').css('margin-left', '320px');
      $(this).addClass('sidebar-open');
      $(this).html('<i class="fa fa-times"></i>');
    } else {
      $('#peptide-sidebar').removeClass('open').css('left', '-320px');
      $('.ml-content').css('margin-left', '0');
      $(this).removeClass('sidebar-open');
      $(this).html('<i class="fa fa-bars"></i>');
    }
  });
  
  // Peptide Sidebar Navigation (SCROLL like ML)
  $(document).on('click', '#peptide-sidebar .ml-sidebar-item', function() {
    var targetSection = $(this).data('target');
    
    // Update active state
    $('#peptide-sidebar .ml-sidebar-item').removeClass('active');
    $(this).addClass('active');
    
    // Scroll to the section if it exists
    var targetElement = $('#' + targetSection);
    if (targetElement.length > 0) {
      $('html, body').stop().animate({
        scrollTop: targetElement.offset().top - 100
      }, 200, 'easeInOutCubic');
    }
    
    // Send to Shiny
    Shiny.setInputValue('peptide_nav_section', targetSection, {priority: "event"});
  });
  
  // ===== PREPROCESS SIDEBAR =====
  var preprocessSidebarOpen = false;
  
  // Preprocess Sidebar Toggle
  $(document).on('click', '#preprocess-sidebar-toggle', function() {
    preprocessSidebarOpen = !preprocessSidebarOpen;
    
    if (preprocessSidebarOpen) {
      $('#preprocess-sidebar').addClass('open').css('left', '0');
      $('.ml-content').css('margin-left', '320px');
      $(this).addClass('sidebar-open');
      $(this).html('<i class="fa fa-times"></i>');
    } else {
      $('#preprocess-sidebar').removeClass('open').css('left', '-320px');
      $('.ml-content').css('margin-left', '0');
      $(this).removeClass('sidebar-open');
      $(this).html('<i class="fa fa-bars"></i>');
    }
  });
  
  // Preprocess Sidebar Navigation (SCROLL like ML)
  $(document).on('click', '#preprocess-sidebar .ml-sidebar-item', function() {
    var targetSection = $(this).data('target');
    
    // Update active state
    $('#preprocess-sidebar .ml-sidebar-item').removeClass('active');
    $(this).addClass('active');
    
    // Scroll to the section if it exists
    var targetElement = $('#' + targetSection);
    if (targetElement.length > 0) {
      $('html, body').stop().animate({
        scrollTop: targetElement.offset().top - 100
      }, 200, 'easeInOutCubic');
    }
    
    // Send to Shiny
    Shiny.setInputValue('preprocess_nav_section', targetSection, {priority: "event"});
  });
  
  // NOTE: hover/active appearance for sidebar items is handled purely in CSS
  // now (.ml-sidebar-item:hover / .ml-sidebar-item.active) to match the METIS
  // theme. The old inline-style handlers were removed.

  // Protein Visualization Sidebar Toggle
  var proteinSidebarOpen = false;
  $(document).on('click', '#protein-sidebar-toggle', function() {
    proteinSidebarOpen = !proteinSidebarOpen;
    
    if (proteinSidebarOpen) {
      $('#protein-sidebar').addClass('open').css('left', '0');
      $('#protein-content').css('margin-left', '320px');
      $(this).addClass('sidebar-open');
      $(this).html('<i class="fa fa-times"></i>');
    } else {
      $('#protein-sidebar').removeClass('open').css('left', '-320px');
      $('#protein-content').css('margin-left', '0');
      $(this).removeClass('sidebar-open');
      $(this).html('<i class="fa fa-bars"></i>');
    }
  });
});

