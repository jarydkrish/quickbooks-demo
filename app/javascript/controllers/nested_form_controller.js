import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template"]
  static values = { wrapperSelector: String }

  add(event) {
    event.preventDefault()
    
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime())
    const wrapper = this.element.querySelector(this.wrapperSelectorValue || '.nested-fields:last-of-type')
    
    if (wrapper) {
      wrapper.insertAdjacentHTML('afterend', content)
    } else {
      this.element.insertAdjacentHTML('beforeend', content)
    }
  }

  remove(event) {
    event.preventDefault()
    
    const wrapper = event.target.closest('.nested-fields')
    
    if (wrapper.querySelector("input[name*='_destroy']")) {
      wrapper.querySelector("input[name*='_destroy']").value = 1
      wrapper.style.display = 'none'
    } else {
      wrapper.remove()
    }
  }
}