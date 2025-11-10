// Load all Stimulus controllers
import { Application } from '@hotwired/stimulus';
import ModalController from './modal_controller';

const application = Application.start();

// Register controllers
application.register('modal', ModalController);

// Configure Stimulus development experience
application.debug = false;
window.Stimulus = application;

export { application };
