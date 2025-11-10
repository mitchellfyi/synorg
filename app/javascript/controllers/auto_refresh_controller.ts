// Auto-refresh controller for periodically updating Turbo Frames
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = {
    interval: { type: Number, default: 5000 }, // Refresh every 5 seconds by default
    url: String
  }

  connect() {
    if (this.urlValue) {
      this.startRefreshing();
    }
  }

  disconnect() {
    this.stopRefreshing();
  }

  startRefreshing() {
    this.stopRefreshing(); // Clear any existing interval
    this.intervalId = setInterval(() => {
      this.refresh();
    }, this.intervalValue);
  }

  stopRefreshing() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  refresh() {
    if (this.urlValue) {
      fetch(this.urlValue, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
        .then(response => response.text())
        .then(html => {
          Turbo.renderStreamMessage(html);
        })
        .catch(error => {
          console.error('Failed to refresh:', error);
        });
    }
  }
}

