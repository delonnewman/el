module El
  class HTMLPage < Page
    abstract!    
    content_type 'text/html'

    class << self
      def style(string = nil)
        styles << string
      end

      def styles
        @styles ||= []
      end

      def title(string = nil)
        if string
          @title = string
        else
          @title || name
        end
      end

      def stylesheets(*paths)
        if paths.empty?
          if @stylesheets
            @stylesheets
          else
            klass = ancestors.select { |klass| klass != self && klass != Page && klass.respond_to?(:stylesheets) }.first
            if klass
              klass.stylesheets
            else
              []
            end
          end
        else
          @stylesheets = paths
        end
      end
    end

    def render_content
      [ ERB.new(DEFAULT_LAYOUT).result(binding) ]
    end
    alias to_html render_content

    [:title, :stylesheets, :styles].each do |method|
      define_method method do
        self.class.send(method)
      end
    end

    def runtime_javascript
      RUNTIME_JAVASCRIPT
    end

    private

    DEFAULT_LAYOUT = <<~HTML
      <!doctype html>
      <html lang="en">
        <head>
          <!-- TODO: generalize this -->
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">

          <title><%= title %></title>
          <% stylesheets.each do |stylesheet| %>
          <link rel="stylesheet" href="<%= stylesheet %>">
          <% end %>

          <% styles.each do |style| %>
          <style><%= style %></style>
          <% end %>
        </head>
        <body>
          <%= content %>
          <script>
            <%= runtime_javascript %>
          </script>
        </body>
      </html>
    HTML

    RUNTIME_JAVASCRIPT = <<~JS
      (function() {

          this.el = this.el || {};
          
          function callAction(actionId, element, result) {
              console.log('calling action', actionId, element);
              var xhr = new XMLHttpRequest();
              xhr.onreadystatechange = function() {
                  var contentType, status, data;
                  if (xhr.readyState === XMLHttpRequest.DONE) {
                      contentType = xhr.getResponseHeader('Content-Type');
                      status = xhr.status;
                      if (status === 0 || (status >= 200 && status < 400)) {
                          if (contentType === 'application/javascript') {
                            eval(xhr.responseText.toString());
                          }
                          else if (contentType === 'application/json') {
                            data = JSON.parse(xhr.responseText.toString());
                            console.log('JSON Data', data);
                            if (data.action_id && data.js) {
                              callAction(data.action_id, element, eval(data.js));
                            }
                            else if (data.action_id) {
                              callAction(data.action_id, element);
                            }
                          }
                          else {
                            console.log(xhr.responseText);
                          }
                      } else {
                          console.error('Something went wrong');
                      }
                  }
              };

              var params = new URLSearchParams();
              // TODO: pass the attributes of the element
              if (result) params.append('result', result);

              xhr.open('POST', '/action/' + actionId);
              xhr.send(params);

              return false;
          }
      
          this.el.actions = {
              call: callAction
          };
      
      }.call(window));
    JS
  end
end