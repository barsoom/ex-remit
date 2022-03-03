export default {
    mounted() {
        this.el.addEventListener("scroll", () => {
            const scrollPerct = this.el.scrollTop / (this.el.scrollHeight - this.el.clientHeight) * 100
            
            if (scrollPerct > 90) {
                console.log("load_more")
                this.pushEvent("load_more")
            }
        }
        )
    },
};