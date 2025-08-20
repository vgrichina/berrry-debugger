// BerrryDebugger Lazy DOM Traversal Functions
// This script provides efficient DOM inspection with lazy loading capabilities

console.log('🚀 LazyDOM script starting execution');

// Utility function to safely post messages
function postLazyDOMMessage(data) {
    try {
        console.log('📤 Posting LazyDOM message:', data.type);
        webkit.messageHandlers.lazyDOMInspector.postMessage(data);
    } catch (e) {
        console.error('❌ Failed to post LazyDOM message:', e);
    }
}

// Test message - verifies message handler is available
try {
    webkit.messageHandlers.lazyDOMInspector.postMessage({
        type: 'test',
        message: 'LazyDOM script loaded'
    });
    console.log('✅ Test message sent - message handler available');
} catch (e) {
    console.error('❌ Failed to send test message - message handler unavailable:', e);
}

window.LazyDOM = {
    // WeakMap for unique element IDs
    elementIds: new WeakMap(),
    idCounter: 0,
    
    // Get unique ID for element
    getElementId: function(element) {
        if (!element || element.nodeType !== Node.ELEMENT_NODE) return '';
        
        if (!this.elementIds.has(element)) {
            this.idCounter++;
            this.elementIds.set(element, 'elem_' + this.idCounter);
        }
        return this.elementIds.get(element);
    },
    
    // Find element by unique ID
    findElementById: function(uniqueId) {
        console.log('🔍 findElementById: Looking for uniqueId:', uniqueId);
        
        // Since WeakMap doesn't support reverse lookup, we'll search the DOM
        // This is less efficient but only used for expansion operations
        const elements = document.querySelectorAll('*');
        let foundCount = 0;
        let elementIds = [];
        
        for (let element of elements) {
            if (this.elementIds.has(element)) {
                foundCount++;
                const elemId = this.elementIds.get(element);
                elementIds.push(elemId);
                if (elemId === uniqueId) {
                    console.log('✅ findElementById: Found element:', element.tagName, 'with ID:', uniqueId);
                    return element;
                }
            }
        }
        
        console.log('❌ findElementById: Element not found. Total elements in WeakMap:', foundCount);
        console.log('❌ findElementById: Available element IDs:', elementIds.join(', '));
        return null;
    },
    
    // Generate CSS selector for element (kept for debugging/display purposes)
    generateSelector: function(element) {
        if (!element || element.nodeType !== Node.ELEMENT_NODE) return '';
        if (element.id) return '#' + element.id;
        
        let path = [];
        let current = element;
        
        while (current && current.nodeType === Node.ELEMENT_NODE && current !== document.body) {
            let selector = current.tagName.toLowerCase();
            
            if (current.className && typeof current.className === 'string' && current.className.trim) {
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
            elementId: this.getElementId(element), // Unique ID for this element
            displaySelector: this.generateSelector(element), // CSS selector for display
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
    
    // Get root element (the actual <html> element) - initial load
    getRootElements: function() {
        console.log('🔍 getRootElements: Starting with document.documentElement');
        const htmlElement = document.documentElement; // This is the <html> element
        console.log('🔍 getRootElements: htmlElement:', htmlElement ? htmlElement.tagName : 'null');
        
        if (!htmlElement) {
            console.log('❌ getRootElements: No HTML element found');
            return [];
        }
        
        // Return the actual HTML root element
        console.log('🔍 getRootElements: About to call getElementInfo for HTML element');
        const elementInfo = this.getElementInfo(htmlElement, 0);
        console.log('🔍 getRootElements: getElementInfo returned:', elementInfo ? 'object' : 'null');
        
        if (elementInfo) {
            console.log('🔍 getRootElements: Returning array with 1 HTML element');
            return [elementInfo];
        }
        
        console.log('❌ getRootElements: getElementInfo returned null, returning empty array');
        return [];
    },
    
    // Get children for specific element ID (lazy load children)
    getChildren: function(uniqueId, parentDepth = null) {
        try {
            console.log('🔍 LazyDOM.getChildren called for unique ID:', uniqueId, 'parentDepth:', parentDepth);
            const element = this.findElementById(uniqueId);
            if (!element) {
                console.log('❌ LazyDOM.getChildren: Element not found for ID:', uniqueId);
                // Send empty children via message
                postLazyDOMMessage({
                    type: 'childElements',
                    elementId: uniqueId,
                    children: []
                });
                return;
            }
            
            const children = [];
            // Calculate child depth: if parentDepth is provided, use it + 1
            // Otherwise, determine depth based on element position
            let childDepth;
            if (parentDepth !== null) {
                childDepth = parentDepth + 1;
                console.log('🔍 Using provided parentDepth:', parentDepth, 'childDepth will be:', childDepth);
            } else {
                // Fallback: calculate depth from document structure
                if (element === document.documentElement) {
                    childDepth = 1; // HTML's children (HEAD, BODY) are depth 1
                } else {
                    // For other elements, try to calculate depth
                    let tempDepth = 0;
                    let tempElement = element;
                    while (tempElement && tempElement !== document.documentElement) {
                        tempDepth++;
                        tempElement = tempElement.parentElement;
                    }
                    childDepth = tempDepth + 1;
                }
                console.log('🔍 Calculated childDepth:', childDepth, 'for element:', element.tagName);
            }
            
            for (let i = 0; i < element.children.length && i < 50; i++) {
                const child = element.children[i];
                if (child.tagName !== 'SCRIPT' && child.tagName !== 'STYLE') {
                    const childInfo = this.getElementInfo(child, childDepth);
                    if (childInfo) {
                        children.push(childInfo);
                    }
                }
            }
            
            console.log('✅ LazyDOM.getChildren: Found', children.length, 'children for', uniqueId);
            
            // Send children via message instead of returning
            postLazyDOMMessage({
                type: 'childElements',
                elementId: uniqueId,
                children: children
            });
            
        } catch (error) {
            console.error('❌ LazyDOM.getChildren error:', error);
            // Send error via message
            postLazyDOMMessage({
                type: 'childElements',
                elementId: uniqueId,
                children: [],
                error: error.message
            });
        }
    },
    
    // Get detailed element info for selected element
    getElementDetails: function(uniqueId) {
        try {
            const element = this.findElementById(uniqueId);
            if (!element) return null;
            
            const elementInfo = this.getElementInfo(element);
            if (elementInfo) {
                // Add additional details for selected elements
                elementInfo.innerHTML = element.innerHTML?.substring(0, 500) || null;
                elementInfo.offsetParent = element.offsetParent ? this.getElementId(element.offsetParent) : null;
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

// Auto-initialize DOM when ready
function initializeLazyDOM() {
    console.log('🚀 initializeLazyDOM() called - readyState:', document.readyState);
    
    if (document.readyState === 'loading') {
        console.log('📋 Document still loading, adding DOMContentLoaded listener');
        document.addEventListener('DOMContentLoaded', initializeLazyDOM);
        return;
    }
    
    try {
        console.log('🔍 Document ready, about to call getRootElements()');
        console.log('🔍 Document body exists:', !!document.body);
        console.log('🔍 Document body children count:', document.body ? document.body.children.length : 'no body');
        
        const rootElements = window.LazyDOM.getRootElements();
        console.log('📊 getRootElements() returned:', typeof rootElements, 'length:', rootElements ? rootElements.length : 'null');
        
        if (rootElements && rootElements.length > 0) {
            console.log('📊 First element example:', rootElements[0]);
        }
        
        if (!rootElements) {
            console.error('❌ getRootElements() returned null/undefined');
            return;
        }
        
        if (rootElements.length === 0) {
            console.error('❌ getRootElements() returned empty array');
            return;
        }
        
        postLazyDOMMessage({
            type: 'rootElements',
            elements: rootElements
        });
        console.log('✅ LazyDOM initialized and sent', rootElements.length, 'root elements');
    } catch (error) {
        console.error('❌ Error in initializeLazyDOM:', error);
        console.error('❌ Error stack:', error.stack);
    }
}

// Don't auto-initialize - wait for explicit request from Swift
// initializeLazyDOM();
console.log('🔍 LazyDOM script loaded - waiting for explicit initialization request');