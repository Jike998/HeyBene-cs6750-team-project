// Mode descriptions
const modeDescriptions = {
    dual: {
        title: 'Dual Joystick',
        description: 'Independent control with two joysticks. Left for steering, right for throttle.'
    },
    arrow: {
        title: 'Arrow Controls',
        description: 'Button-based control. Left/Right arrows for steering, GO/STOP buttons for throttle.'
    },
    onehand: {
        title: 'One Hand Control',
        description: 'Single joystick for both steering and throttle. Move in any direction for full control.'
    }
};

// Current mode
let currentMode = 'dual';

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    initModeSwitcher();
    initDualJoysticks();
    initArrowControls();
    initOneHandJoystick();
});

// Mode Switcher
function initModeSwitcher() {
    const modeButtons = document.querySelectorAll('.mode-btn');

    modeButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const mode = btn.dataset.mode;
            switchMode(mode);
        });
    });
}

function switchMode(mode) {
    if (currentMode === mode) return;

    currentMode = mode;

    // Update buttons
    document.querySelectorAll('.mode-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.mode === mode);
    });

    // Update layouts
    document.querySelectorAll('.control-layout').forEach(layout => {
        layout.classList.remove('active');
    });
    document.getElementById(`${mode}Layout`).classList.add('active');

    // Update description
    updateModeDescription(mode);

    console.log(`Switched to ${mode} mode`);
}

function updateModeDescription(mode) {
    const descriptionTitle = document.querySelector('.description-title');
    const descriptionText = document.querySelector('.description-text');
    const info = modeDescriptions[mode];

    descriptionTitle.textContent = info.title;
    descriptionText.textContent = info.description;
}

// Dual Joystick Controls
function initDualJoysticks() {
    const steeringJoystick = document.getElementById('steeringJoystick');
    const throttleJoystick = document.getElementById('throttleJoystick');

    if (steeringJoystick) setupJoystick(steeringJoystick, 'steering', true, false);
    if (throttleJoystick) setupJoystick(throttleJoystick, 'throttle', false, true);
}

function setupJoystick(joystickEl, type, allowX, allowY) {
    const handle = joystickEl.querySelector('.joystick-handle');
    if (!handle) return;

    let isDragging = false;
    let currentX = 0, currentY = 0;
    const maxDistance = 33; // Maximum distance from center (adjusted for smaller joystick)

    const startDrag = (e) => {
        isDragging = true;
        handle.style.transition = 'none';

        document.addEventListener('mousemove', drag);
        document.addEventListener('mouseup', stopDrag);
        document.addEventListener('touchmove', drag, { passive: false });
        document.addEventListener('touchend', stopDrag);

        e.preventDefault();
    };

    const drag = (e) => {
        if (!isDragging) return;

        const rect = joystickEl.getBoundingClientRect();
        const centerX = rect.width / 2;
        const centerY = rect.height / 2;

        let clientX, clientY;
        if (e.type === 'touchmove') {
            clientX = e.touches[0].clientX;
            clientY = e.touches[0].clientY;
        } else {
            clientX = e.clientX;
            clientY = e.clientY;
        }

        let deltaX = allowX ? (clientX - rect.left - centerX) : 0;
        let deltaY = allowY ? (clientY - rect.top - centerY) : 0;

        // Limit to circle
        const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
        if (distance > maxDistance) {
            const angle = Math.atan2(deltaY, deltaX);
            deltaX = Math.cos(angle) * maxDistance;
            deltaY = Math.sin(angle) * maxDistance;
        }

        currentX = deltaX;
        currentY = deltaY;

        handle.style.transform = `translate(${deltaX}px, ${deltaY}px)`;

        // Calculate normalized values (-1 to 1)
        const normalizedX = deltaX / maxDistance;
        const normalizedY = -deltaY / maxDistance; // Invert Y axis

        updateControlValue(type, normalizedX, normalizedY);

        e.preventDefault();
    };

    const stopDrag = () => {
        if (!isDragging) return;

        isDragging = false;

        // Return to center with animation
        handle.style.transition = 'transform 0.2s cubic-bezier(0.4, 0, 0.2, 1)';
        handle.style.transform = 'translate(0, 0)';
        currentX = 0;
        currentY = 0;

        updateControlValue(type, 0, 0);

        document.removeEventListener('mousemove', drag);
        document.removeEventListener('mouseup', stopDrag);
        document.removeEventListener('touchmove', drag);
        document.removeEventListener('touchend', stopDrag);
    };

    handle.addEventListener('mousedown', startDrag);
    handle.addEventListener('touchstart', startDrag, { passive: false });
}

// Arrow Controls
function initArrowControls() {
    const leftArrow = document.getElementById('leftArrow');
    const rightArrow = document.getElementById('rightArrow');
    const goBtn = document.getElementById('goBtn');
    const stopBtn = document.getElementById('stopBtn');

    let steering = 0;
    let throttle = 0;

    // Arrow buttons
    if (leftArrow) {
        leftArrow.addEventListener('mousedown', () => {
            leftArrow.classList.add('pressed');
            steering = -1;
            updateControlValue('arrow-steering', steering, 0);
        });
        leftArrow.addEventListener('mouseup', () => {
            leftArrow.classList.remove('pressed');
            steering = 0;
            updateControlValue('arrow-steering', steering, 0);
        });
        leftArrow.addEventListener('mouseleave', () => {
            leftArrow.classList.remove('pressed');
            steering = 0;
            updateControlValue('arrow-steering', steering, 0);
        });

        leftArrow.addEventListener('touchstart', (e) => {
            e.preventDefault();
            leftArrow.classList.add('pressed');
            steering = -1;
            updateControlValue('arrow-steering', steering, 0);
        });
        leftArrow.addEventListener('touchend', (e) => {
            e.preventDefault();
            leftArrow.classList.remove('pressed');
            steering = 0;
            updateControlValue('arrow-steering', steering, 0);
        });
    }

    if (rightArrow) {
        rightArrow.addEventListener('mousedown', () => {
            rightArrow.classList.add('pressed');
            steering = 1;
            updateControlValue('arrow-steering', steering, 0);
        });
        rightArrow.addEventListener('mouseup', () => {
            rightArrow.classList.remove('pressed');
            steering = 0;
            updateControlValue('arrow-steering', steering, 0);
        });
        rightArrow.addEventListener('mouseleave', () => {
            rightArrow.classList.remove('pressed');
            steering = 0;
            updateControlValue('arrow-steering', steering, 0);
        });

        rightArrow.addEventListener('touchstart', (e) => {
            e.preventDefault();
            rightArrow.classList.add('pressed');
            steering = 1;
            updateControlValue('arrow-steering', steering, 0);
        });
        rightArrow.addEventListener('touchend', (e) => {
            e.preventDefault();
            rightArrow.classList.remove('pressed');
            steering = 0;
            updateControlValue('arrow-steering', steering, 0);
        });
    }

    // GO/STOP buttons
    if (goBtn) {
        goBtn.addEventListener('mousedown', () => {
            goBtn.classList.add('pressed');
            throttle = 1;
            updateControlValue('arrow-throttle', 0, throttle);
        });
        goBtn.addEventListener('mouseup', () => {
            goBtn.classList.remove('pressed');
            throttle = 0;
            updateControlValue('arrow-throttle', 0, throttle);
        });
        goBtn.addEventListener('mouseleave', () => {
            goBtn.classList.remove('pressed');
            throttle = 0;
            updateControlValue('arrow-throttle', 0, throttle);
        });

        goBtn.addEventListener('touchstart', (e) => {
            e.preventDefault();
            goBtn.classList.add('pressed');
            throttle = 1;
            updateControlValue('arrow-throttle', 0, throttle);
        });
        goBtn.addEventListener('touchend', (e) => {
            e.preventDefault();
            goBtn.classList.remove('pressed');
            throttle = 0;
            updateControlValue('arrow-throttle', 0, throttle);
        });
    }

    if (stopBtn) {
        stopBtn.addEventListener('mousedown', () => {
            stopBtn.classList.add('pressed');
            throttle = -1;
            updateControlValue('arrow-throttle', 0, throttle);
        });
        stopBtn.addEventListener('mouseup', () => {
            stopBtn.classList.remove('pressed');
            throttle = 0;
            updateControlValue('arrow-throttle', 0, throttle);
        });
        stopBtn.addEventListener('mouseleave', () => {
            stopBtn.classList.remove('pressed');
            throttle = 0;
            updateControlValue('arrow-throttle', 0, throttle);
        });

        stopBtn.addEventListener('touchstart', (e) => {
            e.preventDefault();
            stopBtn.classList.add('pressed');
            throttle = -1;
            updateControlValue('arrow-throttle', 0, throttle);
        });
        stopBtn.addEventListener('touchend', (e) => {
            e.preventDefault();
            stopBtn.classList.remove('pressed');
            throttle = 0;
            updateControlValue('arrow-throttle', 0, throttle);
        });
    }
}

// One Hand Joystick
function initOneHandJoystick() {
    const joystickEl = document.getElementById('onehandJoystick');
    if (!joystickEl) return;

    const handle = joystickEl.querySelector('.onehand-handle');
    if (!handle) return;

    let isDragging = false;
    let currentX = 0, currentY = 0;
    const maxDistance = 52; // Maximum distance from center (adjusted for smaller joystick)

    const startDrag = (e) => {
        isDragging = true;
        handle.style.transition = 'none';

        document.addEventListener('mousemove', drag);
        document.addEventListener('mouseup', stopDrag);
        document.addEventListener('touchmove', drag, { passive: false });
        document.addEventListener('touchend', stopDrag);

        e.preventDefault();
    };

    const drag = (e) => {
        if (!isDragging) return;

        const rect = joystickEl.getBoundingClientRect();
        const centerX = rect.width / 2;
        const centerY = rect.height / 2;

        let clientX, clientY;
        if (e.type === 'touchmove') {
            clientX = e.touches[0].clientX;
            clientY = e.touches[0].clientY;
        } else {
            clientX = e.clientX;
            clientY = e.clientY;
        }

        let deltaX = clientX - rect.left - centerX;
        let deltaY = clientY - rect.top - centerY;

        // Limit to circle
        const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
        if (distance > maxDistance) {
            const angle = Math.atan2(deltaY, deltaX);
            deltaX = Math.cos(angle) * maxDistance;
            deltaY = Math.sin(angle) * maxDistance;
        }

        currentX = deltaX;
        currentY = deltaY;

        handle.style.transform = `translate(${deltaX}px, ${deltaY}px)`;

        // Calculate normalized values (-1 to 1)
        const normalizedX = deltaX / maxDistance; // Steering
        const normalizedY = -deltaY / maxDistance; // Throttle (inverted)

        updateControlValue('onehand', normalizedX, normalizedY);

        e.preventDefault();
    };

    const stopDrag = () => {
        if (!isDragging) return;

        isDragging = false;

        // Return to center with animation
        handle.style.transition = 'transform 0.2s cubic-bezier(0.4, 0, 0.2, 1)';
        handle.style.transform = 'translate(0, 0)';
        currentX = 0;
        currentY = 0;

        updateControlValue('onehand', 0, 0);

        document.removeEventListener('mousemove', drag);
        document.removeEventListener('mouseup', stopDrag);
        document.removeEventListener('touchmove', drag);
        document.removeEventListener('touchend', stopDrag);
    };

    handle.addEventListener('mousedown', startDrag);
    handle.addEventListener('touchstart', startDrag, { passive: false });
}

// Update control values
function updateControlValue(type, x, y) {
    switch(type) {
        case 'steering':
            console.log(`Steering: ${x.toFixed(2)}`);
            break;
        case 'throttle':
            console.log(`Throttle: ${y.toFixed(2)}`);
            break;
        case 'arrow-steering':
            console.log(`Arrow Steering: ${x.toFixed(2)}`);
            break;
        case 'arrow-throttle':
            console.log(`Arrow Throttle: ${y.toFixed(2)}`);
            break;
        case 'onehand':
            console.log(`One Hand - Steering: ${x.toFixed(2)}, Throttle: ${y.toFixed(2)}`);
            break;
    }
}
