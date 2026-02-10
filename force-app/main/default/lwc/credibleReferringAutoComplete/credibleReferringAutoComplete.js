import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { FlowNavigationFinishEvent } from 'lightning/flowSupport';

import PROVIDERS_SR from '@salesforce/resourceUrl/Referral_Provider';
import NPI_SR from '@salesforce/resourceUrl/Referral_Npi';
import saveProviderNpi from '@salesforce/apex/ProviderNpiSaveService.saveProviderNpi';

export default class CredibleReferringAutoComplete extends LightningElement {
  @api recordId;

  @track providerValue = '';
  @track providerOptions = [];
  providers = [];

  @track npiValue = '';
  @track npiOptions = [];
  npis = [];

  providerTimer;
  npiTimer;

  connectedCallback() {
    fetch(PROVIDERS_SR).then(r => r.json())
      .then(data => { this.providers = data?.names || []; })
      .catch(e => console.error('Error loading Referral_Provider:', e));

    fetch(NPI_SR).then(r => r.json())
      .then(data => { this.npis = data?.provider_npi || []; })
      .catch(e => console.error('Error loading Referral_Npi:', e));
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
    this.providerValue = e.currentTarget.dataset.value;
    this.providerOptions = [];
  }

  // NPI
  onNpiChange(e) {
    this.npiValue = e.target.value;
    window.clearTimeout(this.npiTimer);

    const q = (this.npiValue || '').trim();
    if (q.length < 2) { this.npiOptions = []; return; }

    this.npiTimer = window.setTimeout(() => {
      this.npiOptions = this.npis
        .filter(x => (x || '').includes(q))
        .slice(0, 50);
    }, 150);
  }

  selectNpi(e) {
    this.npiValue = e.currentTarget.dataset.value;
    this.npiOptions = [];
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