// Modal controller for displaying run logs and other content
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = {
    content: String
  }

  open(event) {
    event.preventDefault();
    let content = this.contentValue || event.currentTarget.dataset.modalContentValue;
    
    // Content is already a string, use as-is
    const modal = this.createModal(content);
    document.body.appendChild(modal);
    modal.showModal();
  }

  createModal(content) {
    const dialog = document.createElement('dialog');
    dialog.className = 'fixed inset-0 z-50 overflow-y-auto';
    dialog.innerHTML = `
      <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
      <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
        <div class="relative transform overflow-hidden rounded-lg bg-white text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg">
          <div class="bg-white px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
            <div class="sm:flex sm:items-start">
              <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left w-full">
                <h3 class="text-base font-semibold leading-6 text-gray-900 mb-4">Run Logs</h3>
                <div class="mt-2">
                  <pre class="text-sm text-gray-500 whitespace-pre-wrap bg-gray-50 p-4 rounded max-h-96 overflow-y-auto">${this.escapeHtml(content)}</pre>
                </div>
              </div>
            </div>
          </div>
          <div class="bg-gray-50 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
            <button type="button" class="inline-flex w-full justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 sm:ml-3 sm:w-auto" data-action="click->modal#close">Close</button>
          </div>
        </div>
      </div>
    `;

    const closeButton = dialog.querySelector('button[data-action="click->modal#close"]');
    closeButton.addEventListener('click', () => this.close(dialog));
    dialog.addEventListener('click', (e) => {
      if (e.target === dialog) {
        this.close(dialog);
      }
    });

    return dialog;
  }

  close(dialog) {
    dialog.close();
    dialog.remove();
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
}

