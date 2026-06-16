document.addEventListener('DOMContentLoaded', () => {
    // Initialize Lucide icons
    lucide.createIcons();

    // Reset scroll to top and clear hash on page refresh
    if ('scrollRestoration' in history) {
        history.scrollRestoration = 'manual';
    }
    window.scrollTo(0, 0);
    if (window.location.hash) {
        history.replaceState(null, null, ' ');
    }

    // Elements
    const header = document.querySelector('.header');
    const sections = document.querySelectorAll('section[id]');
    const navLinks = document.querySelectorAll('.nav-link');
    const mobileMenuToggle = document.querySelector('.mobile-menu-toggle');
    const navLinksContainer = document.querySelector('.nav-links');

    // 1. Header scroll effect
    window.addEventListener('scroll', () => {
        if (window.scrollY > 20) {
            header.classList.add('scrolled');
        } else {
            header.classList.remove('scrolled');
        }
    });

    // 2. Scrollspy - Highlight active link based on scroll position
    window.addEventListener('scroll', () => {
        let currentSectionId = '';
        const scrollPosition = window.scrollY + 160; // offset for nav bar

        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.clientHeight;

            if (scrollPosition >= sectionTop && scrollPosition < sectionTop + sectionHeight) {
                currentSectionId = section.getAttribute('id');
            }
        });

        // Fallback for bottom of page (sometimes scroll spy doesn't trigger on footer sections)
        if ((window.innerHeight + window.scrollY) >= document.documentElement.scrollHeight - 60) {
            currentSectionId = 'contact';
        }

        if (currentSectionId) {
            navLinks.forEach(link => {
                link.classList.remove('active');
                if (link.getAttribute('href').slice(1) === currentSectionId) {
                    link.classList.add('active');
                }
            });
        }
    });

    // 3. Mobile Navigation Menu Toggle
    mobileMenuToggle.addEventListener('click', () => {
        navLinksContainer.classList.toggle('mobile-active');
        
        // Dynamic icon switch (menu -> close)
        const icon = mobileMenuToggle.querySelector('i');
        if (navLinksContainer.classList.contains('mobile-active')) {
            icon.setAttribute('data-lucide', 'x');
        } else {
            icon.setAttribute('data-lucide', 'menu');
        }
        lucide.createIcons();
    });

    

    // Close mobile menu when clicking a link
    navLinks.forEach(link => {
        link.addEventListener('click', () => {
            navLinksContainer.classList.remove('mobile-active');
            const icon = mobileMenuToggle.querySelector('i');
            icon.setAttribute('data-lucide', 'menu');
            lucide.createIcons();
        });
    });

    // 4. Contact Form Handling
    const contactForm = document.querySelector('.contact-form');
    if (contactForm) {
        contactForm.addEventListener('submit', (e) => {
            e.preventDefault();
            
            const submitBtn = contactForm.querySelector('.btn-submit');
            const originalContent = submitBtn.innerHTML;
            
            // Show sending state
            submitBtn.disabled = true;
            submitBtn.innerHTML = 'Sending... <i data-lucide="loader" class="btn-icon animate-spin"></i>';
            lucide.createIcons();

            // Simulate form submission
            setTimeout(() => {
                // Restore button state
                submitBtn.disabled = false;
                submitBtn.innerHTML = 'Message Sent! <i data-lucide="check" class="btn-icon"></i>';
                lucide.createIcons();
                
                // Clear form inputs
                contactForm.reset();
                

                // Create success toast notification
                showToast("Your message has been sent successfully!");

                // Reset button back to original state after 3 seconds
                setTimeout(() => {
                    submitBtn.innerHTML = originalContent;
                    lucide.createIcons();
                }, 3000);
            }, 1500);
        });
    }

    // Toast Notification helper
    function showToast(message) {
        const toast = document.createElement('div');
        toast.className = 'toast-notification';
        toast.innerHTML = `<i data-lucide="check-circle-2"></i> <span>${message}</span>`;
        document.body.appendChild(toast);
        lucide.createIcons();

        // Animate in
        setTimeout(() => toast.classList.add('show'), 100);

        // Animate out and remove
        setTimeout(() => {
            toast.classList.remove('show');
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }
});
