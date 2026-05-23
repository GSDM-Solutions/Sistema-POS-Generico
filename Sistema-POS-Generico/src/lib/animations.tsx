/* eslint-disable react-refresh/only-export-components */
/**
 * Utilidades de animación CSS para el sistema POS
 * Alternativa ligera a Framer Motion
 */

// Clases de animación para usar con Tailwind
export const animations = {
    // Fade
    fadeIn: 'animate-in fade-in duration-300',
    fadeOut: 'animate-out fade-out duration-200',

    // Slide
    slideInFromTop: 'animate-in slide-in-from-top-2 duration-300',
    slideInFromBottom: 'animate-in slide-in-from-bottom-2 duration-300',
    slideInFromLeft: 'animate-in slide-in-from-left-2 duration-300',
    slideInFromRight: 'animate-in slide-in-from-right-2 duration-300',

    // Scale
    scaleIn: 'animate-in zoom-in-95 duration-200',
    scaleOut: 'animate-out zoom-out-95 duration-150',

    // Bounce
    bounce: 'animate-bounce',

    // Spin
    spin: 'animate-spin',

    // Pulse
    pulse: 'animate-pulse',

    // Combinaciones comunes
    modalEnter: 'animate-in fade-in zoom-in-95 duration-200',
    modalExit: 'animate-out fade-out zoom-out-95 duration-150',
    toastEnter: 'animate-in slide-in-from-top-2 fade-in duration-300',
    toastExit: 'animate-out slide-in-from-top-2 fade-out duration-200',
    cardHover: 'transition-all duration-200 hover:scale-105 hover:shadow-lg',
    buttonPress: 'transition-transform active:scale-95',
};

// Hook para animaciones programáticas
export function useAnimation() {
    const animate = (
        element: HTMLElement,
        animation: keyof typeof animations,
        onComplete?: () => void
    ) => {
        const animationClass = animations[animation];
        element.classList.add(...animationClass.split(' '));

        const handleAnimationEnd = () => {
            element.classList.remove(...animationClass.split(' '));
            onComplete?.();
            element.removeEventListener('animationend', handleAnimationEnd);
        };

        element.addEventListener('animationend', handleAnimationEnd);
    };

    return { animate };
}

// Componente wrapper para animaciones
interface AnimatedProps {
    children: React.ReactNode;
    animation?: keyof typeof animations;
    delay?: number;
    className?: string;
}

export function Animated({
    children,
    animation = 'fadeIn',
    delay = 0,
    className = ''
}: AnimatedProps) {
    const style = delay > 0 ? { animationDelay: `${delay}ms` } : undefined;

    return (
        <div
            className={`${animations[animation]} ${className}`}
            style={style}
        >
            {children}
        </div>
    );
}

// Animaciones de lista (stagger)
export function AnimatedList({
    children,
    staggerDelay = 50
}: {
    children: React.ReactNode[];
    staggerDelay?: number;
}) {
    return (
        <>
            {React.Children.map(children, (child, index) => (
                <Animated
                    animation="slideInFromLeft"
                    delay={index * staggerDelay}
                >
                    {child}
                </Animated>
            ))}
        </>
    );
}

// Micro-interacciones
export const microInteractions = {
    // Botón con efecto ripple
    ripple: (e: React.MouseEvent<HTMLElement>) => {
        const button = e.currentTarget;
        const ripple = document.createElement('span');
        const rect = button.getBoundingClientRect();
        const size = Math.max(rect.width, rect.height);
        const x = e.clientX - rect.left - size / 2;
        const y = e.clientY - rect.top - size / 2;

        ripple.style.width = ripple.style.height = `${size}px`;
        ripple.style.left = `${x}px`;
        ripple.style.top = `${y}px`;
        ripple.classList.add('ripple');

        button.appendChild(ripple);

        setTimeout(() => ripple.remove(), 600);
    },

    // Shake (para errores)
    shake: (element: HTMLElement) => {
        element.classList.add('animate-shake');
        setTimeout(() => element.classList.remove('animate-shake'), 500);
    },

    // Success checkmark
    successPulse: (element: HTMLElement) => {
        element.classList.add('animate-success-pulse');
        setTimeout(() => element.classList.remove('animate-success-pulse'), 1000);
    }
};

// CSS personalizado para agregar a index.css
export const customAnimationsCSS = `
/* Ripple effect */
.ripple {
    position: absolute;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.6);
    transform: scale(0);
    animation: ripple-animation 600ms ease-out;
    pointer-events: none;
}

@keyframes ripple-animation {
    to {
        transform: scale(4);
        opacity: 0;
    }
}

/* Shake animation */
@keyframes shake {
    0%, 100% { transform: translateX(0); }
    10%, 30%, 50%, 70%, 90% { transform: translateX(-5px); }
    20%, 40%, 60%, 80% { transform: translateX(5px); }
}

.animate-shake {
    animation: shake 0.5s ease-in-out;
}

/* Success pulse */
@keyframes success-pulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.1); }
}

.animate-success-pulse {
    animation: success-pulse 0.6s ease-in-out;
}

/* Smooth transitions */
.transition-smooth {
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

/* Hover lift */
.hover-lift {
    transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.hover-lift:hover {
    transform: translateY(-2px);
    box-shadow: 0 10px 20px rgba(0, 0, 0, 0.1);
}
`;
