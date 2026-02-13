import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { FlowNavigationFinishEvent } from 'lightning/flowSupport';

import saveProviderNpi from '@salesforce/apex/ProviderNpiSaveService.saveProviderNpi';
import getProviderNpiMap from '@salesforce/apex/ProviderNpiMapService.getProviderNpiMap';

export default class CredibleReferringAutoComplete extends LightningElement {
  @api recordId;

  @track providerValue = '';
  @track providerOptions = [];
  providers = [];

  @track npiValue = '';

  providerNpiMap = {};
  providerTimer;

  @wire(getProviderNpiMap)
  wiredProviderNpiMap({ error, data }) {
    if (data) {
      this.providerNpiMap = data;
      this.providers = Object.keys(data);
    } else if (error) {
      console.error('Error loading provider-NPI map:', error);
    }
  }

  // Provider
  onProviderChange(e) {
    this.providerValue = e.target.value;
    window.clearTimeout(this.providerTimer);

    const q = (this.providerValue || '').trim();
    if (q.length < 2) { this.providerOptions = []; return; }

    this.providerTimer = window.setTimeout(() => {
      const low = q.toLowerCase();
      this.providerOptions = this.providers
        .filter(x => (x || '').toLowerCase().includes(low))
        .slice(0, 50);
    }, 150);
  }

  selectProvider(e) {
    const selected = e.currentTarget.dataset.value;
    this.providerValue = selected;
    this.providerOptions = [];

    // Auto-populate NPI from the map
    const npi = this.providerNpiMap[selected];
    if (npi) {
      this.npiValue = npi;
    }
  }

  async handleSave() {
    const provider = (this.providerValue || '').trim();
    const npi = (this.npiValue || '').trim();

    if (!provider || !npi) {
      this.toast('Missing info', 'Provider and NPI are required.', 'error');
      return;
    }

    try {
      await saveProviderNpi({
        oppId: this.recordId,
        providerValue: provider,
        npiValue: npi
      });

      getRecordNotifyChange([{ recordId: this.recordId }]);

      this.toast('Saved', 'Provider & NPI updated successfully.', 'success');

      // CLOSE the flow modal
      this.dispatchEvent(new FlowNavigationFinishEvent());
    } catch (err) {
      console.error(err);
      this.toast('Save failed', err?.body?.message || err?.message || 'Unknown error', 'error');
    }
  }

  handleCancel() {
    // Close the flow modal
    this.dispatchEvent(new FlowNavigationFinishEvent());
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
