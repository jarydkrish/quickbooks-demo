import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.close = this.close.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    document.addEventListener("click", this.close)
    document.addEventListener("keydown", this.handleKeydown)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown = (event) => {
    if (event.key === "Escape") {
      this.close()
    }
  }
}