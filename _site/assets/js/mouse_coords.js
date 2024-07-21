const header = document.querySelector('.header')


const maxTranslateY = -57;
const maxScroll = 500;

window.addEventListener('scroll', () => {
  let scrollPosition = window.pageYOffset || document.documentElement.scrollTop;
  console.log('Scroll Position:', scrollPosition);
  let transformValue = -1 * maxTranslateY - (scrollPosition / maxScroll) * maxTranslateY;
  if (transformValue < 0) transformValue = 0; // Ensure the value doesn't go below 0




  header.style.transform = `translateY(${transformValue}px)`;
});

var lazyLoadInstance = new LazyLoad({
  // Your custom settings go here
});