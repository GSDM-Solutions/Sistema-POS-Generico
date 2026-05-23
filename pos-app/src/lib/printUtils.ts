export function openPrintWindow(content: string) {
  const iframe = document.createElement('iframe');
  iframe.style.position = 'fixed';
  iframe.style.right = '0';
  iframe.style.bottom = '0';
  iframe.style.width = '0';
  iframe.style.height = '0';
  iframe.style.border = 'none';

  document.body.appendChild(iframe);

  const iframeDoc = iframe.contentDocument || iframe.contentWindow?.document;
  if (!iframeDoc) return;

  iframeDoc.open();
  iframeDoc.write(content);
  iframeDoc.close();

  const iframeWindow = iframe.contentWindow;
  if (!iframeWindow) return;

  iframeWindow.focus();
  iframeWindow.print();

  iframeWindow.onafterprint = () => {
    document.body.removeChild(iframe);
  };

  setTimeout(() => {
    if (document.body.contains(iframe)) {
      document.body.removeChild(iframe);
    }
  }, 3000);
}
