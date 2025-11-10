import { Application } from '@hotwired/stimulus';

declare global {
  interface Window {
    Stimulus: Application;
  }

  // Turbo global from @hotwired/turbo-rails
  const Turbo: {
    renderStreamMessage: (html: string) => void;
    visit: (url: string) => void;
  };
}

export {};
