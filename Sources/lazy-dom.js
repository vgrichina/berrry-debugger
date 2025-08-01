// BerrryDebugger Lazy DOM Traversal Functions
// This script provides efficient DOM inspection with lazy loading capabilities

window.LazyDOM = {
    // Generate CSS selector for element
    generateSelector: function(element) {
        if (!element || element.nodeType !== Node.ELEMENT_NODE) return '';
        if (element.id) return '#' + element.id;
        
        let path = [];
        let current = element;
        
        while (current && current.nodeType === Node.ELEMENT_NODE && current !== document.body) {
            let selector = current.tagName.toLowerCase();
            
            if (current.className) {
                const classes = current.className.trim().split(/\s+/).slice(0, 2);
                if (classes.length > 0 && classes[0]) {
                    selector += '.' + classes.join('.');
                }
            }
            
            // Add nth-child if there are siblings with same tag
            const siblings = Array.from(current.parentNode?.children || [])
                .filter(el => el.tagName === current.tagName);
            if (siblings.length > 1) {
                const index = siblings.indexOf(current) + 1;
                selector += ':nth-child(' + index + ')';
            }
            
            path.unshift(selector);
            current = current.parentNode;
            
            if (path.length > 4) break; // Limit selector depth
        }
        
        return path.join(' > ');
    },
    
    // Get element info without children (lazy loading)
    getElementInfo: function(element, depth = 0) {
        if (!element || element.nodeType !== Node.ELEMENT_NODE) return null;
        
        const rect = element.getBoundingClientRect();
        const styles = window.getComputedStyle(element);
        
        const attributes = {};
        for (let attr of element.attributes) {
            attributes[attr.name] = attr.value;
        }
        
        return {
            tagName: element.tagName,
            id: element.id || null,
            className: element.className || null,
            attributes: attributes,
            textContent: element.textContent?.trim().substring(0, 200) || null,
            selector: this.generateSelector(element),
            hasChildren: element.children.length > 0,
            childCount: element.children.length,
            depth: depth,
            dimensions: {
                width: Math.round(rect.width),
                height: Math.round(rect.height),
                top: Math.round(rect.top + window.scrollY),
                left: Math.round(rect.left + window.scrollX)
            },
            styles: {
                display: styles.display,
                position: styles.position,
                color: styles.color,
                backgroundColor: styles.backgroundColor,
                fontSize: styles.fontSize,
                fontFamily: styles.fontFamily,
                margin: styles.margin,
                padding: styles.padding,
                border: styles.border,
                zIndex: styles.zIndex
            }
        };
    },
    
    // Get root elements (body children) - initial load
    getRootElements: function() {
        const body = document.body;
        if (!body) return [];
        
        const rootElements = [];
        for (let i = 0; i < body.children.length && i < 30; i++) {
            const child = body.children[i];
            if (child.tagName !== 'SCRIPT' && child.tagName !== 'STYLE') {
                const elementInfo = this.getElementInfo(child, 1);
                if (elementInfo) {
                    rootElements.push(elementInfo);
                }
            }
        }
        
        return rootElements;
    },
    
    // Get children for specific selector (lazy load children)
    getChildren: function(selector) {
        try {
            const element = document.querySelector(selector);
            if (!element) return [];
            
            const children = [];
            const currentDepth = (selector.split('>').length) + 1;
            
            for (let i = 0; i < element.children.length && i < 50; i++) {
                const child = element.children[i];
                if (child.tagName !== 'SCRIPT' && child.tagName !== 'STYLE') {
                    const childInfo = this.getElementInfo(child, currentDepth);
                    if (childInfo) {
                        children.push(childInfo);
                    }
                }
            }
            
            return children;
        } catch (error) {
            console.error('LazyDOM.getChildren error:', error);
            return [];
        }
    },
    
    // Get detailed element info for selected element
    getElementDetails: function(selector) {
        try {
            const element = document.querySelector(selector);
            if (!element) return null;
            
            const elementInfo = this.getElementInfo(element);
            if (elementInfo) {
                // Add additional details for selected elements
                elementInfo.innerHTML = element.innerHTML?.substring(0, 500) || null;
                elementInfo.offsetParent = element.offsetParent ? this.generateSelector(element.offsetParent) : null;
                elementInfo.scrollTop = element.scrollTop;
                elementInfo.scrollLeft = element.scrollLeft;
            }
            
            return elementInfo;
        } catch (error) {
            console.error('LazyDOM.getElementDetails error:', error);
            return null;
        }
    },
    
    // Search elements by query string
    searchElements: function(query) {
        if (!query || query.trim() === '') return [];
        
        try {
            const results = [];
            const lowerQuery = query.toLowerCase();
            const elements = document.querySelectorAll('*');
            
            for (let element of elements) {
                if (element.tagName === 'SCRIPT' || element.tagName === 'STYLE') continue;
                
                const tagMatch = element.tagName.toLowerCase().includes(lowerQuery);
                const idMatch = element.id && element.id.toLowerCase().includes(lowerQuery);
                const classMatch = element.className && element.className.toLowerCase().includes(lowerQuery);
                const textMatch = element.textContent && 
                    element.textContent.toLowerCase().includes(lowerQuery) &&
                    element.textContent.trim().length < 100; // Avoid matching large text blocks
                
                if (tagMatch || idMatch || classMatch || textMatch) {
                    const elementInfo = this.getElementInfo(element);
                    if (elementInfo) {
                        results.push(elementInfo);
                    }
                    if (results.length >= 20) break; // Limit results
                }
            }
            
            return results;
        } catch (error) {
            console.error('LazyDOM.searchElements error:', error);
            return [];
        }
    },
    
    // Highlight element on page (for element selection)
    highlightElement: function(selector) {
        try {
            // Remove previous highlights
            const previousHighlights = document.querySelectorAll('.berrry-debugger-highlight');
            previousHighlights.forEach(el => el.classList.remove('berrry-debugger-highlight'));
            
            // Add highlight to selected element
            const element = document.querySelector(selector);
            if (element) {
                // Add CSS for highlighting if not already present
                if (!document.getElementById('berrry-debugger-styles')) {
                    const style = document.createElement('style');
                    style.id = 'berrry-debugger-styles';
                    style.textContent = `
                        .berrry-debugger-highlight {
                            outline: 2px solid #007AFF !important;
                            outline-offset: -2px !important;
                            background-color: rgba(0, 122, 255, 0.1) !important;
                        }
                    `;
                    document.head.appendChild(style);
                }
                
                element.classList.add('berrry-debugger-highlight');
                element.scrollIntoView({ behavior: 'smooth', block: 'center' });
                return true;
            }
            return false;
        } catch (error) {
            console.error('LazyDOM.highlightElement error:', error);
            return false;
        }
    },
    
    // Remove all highlights
    removeHighlights: function() {
        try {
            const highlights = document.querySelectorAll('.berrry-debugger-highlight');
            highlights.forEach(el => el.classList.remove('berrry-debugger-highlight'));
            return true;
        } catch (error) {
            console.error('LazyDOM.removeHighlights error:', error);
            return false;
        }
    },
    
    // Get page statistics
    getPageStats: function() {
        try {
            const allElements = document.querySelectorAll('*');
            const scriptElements = document.querySelectorAll('script');
            const styleElements = document.querySelectorAll('style, link[rel="stylesheet"]');
            const imageElements = document.querySelectorAll('img');
            
            return {
                totalElements: allElements.length,
                scriptElements: scriptElements.length,
                styleElements: styleElements.length,
                imageElements: imageElements.length,
                url: window.location.href,
                title: document.title,
                readyState: document.readyState
            };
        } catch (error) {
            console.error('LazyDOM.getPageStats error:', error);
            return null;
        }
    }
};

// Initialize and log readiness
console.log('🌳 LazyDOM functions initialized and ready');