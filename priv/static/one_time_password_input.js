export default {
  mounted() {
    const inputs = this.el.querySelectorAll('input');

    inputs.forEach((input, index) => {
      // Select text on focus
      input.addEventListener('focus', (e) => {
        e.target.select();
      });

      // Allow only numbers and navigation
      input.addEventListener('keydown', (e) => {
        if (e.key === 'ArrowLeft' && index > 0) {
          e.preventDefault();
          inputs[index - 1].focus();
        }

        if (e.key === 'ArrowRight' && index < inputs.length - 1) {
          e.preventDefault();
          inputs[index + 1].focus();
        }

        if (e.key === 'Backspace' && !input.value && index > 0) {
          inputs[index - 1].focus();
          inputs[index - 1].value = '';
        }
      });

      input.addEventListener('input', (e) => {
        const value = e.target.value;
        if (value.length > 0) {
          input.value = value[value.length - 1].replace(/[^0-9]/g, '');

          // Move to next input
          if (index < inputs.length - 1) {
            inputs[index + 1].focus();
          }
        }
      });

      // Handle paste
      input.addEventListener('paste', (e) => {
        e.preventDefault();
        const pastedData = e.clipboardData.getData('text');
        const numbers = pastedData.replace(/[^0-9]/g, '').split('');

        inputs.forEach((input, i) => {
          if (numbers[i]) {
            input.value = numbers[i];
          }
        });

        // Move cursor to last input on paste
        inputs[inputs.length - 1].focus();

        // Call LiveView to verify this code
        this.pushEvent('verify', { auth: { password: numbers } }, (reply, ref) => { })
      });
    });
  }
};
