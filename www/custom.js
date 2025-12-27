/* ============================================================================
 * MicroarrAI - Custom JavaScript
 * ============================================================================
 * Description: Scroll-based tile animation for Home page
 * Author: Sergio Olmos Piñero et al.
 * ============================================================================
 */

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
