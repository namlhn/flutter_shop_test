import 'dart:async';

import 'package:eshop/Helper/Color.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../ui/styles/DesignConfig.dart';

class WebviewCustom extends StatefulWidget {
  final String appName;
  final String url;
  const WebviewCustom({Key? key, required this.appName, required this.url}) : super(key: key);

  @override
  State<WebviewCustom> createState() => _WebviewCustomState();
}

class _WebviewCustomState extends State<WebviewCustom> {
  String message = "";
  bool isloading = true;
  final Completer<WebViewController> _controller = Completer<WebViewController>();
  DateTime? currentBackPressTime;

  @override
  Widget build(BuildContext context) {
    return   Scaffold(
      //  key: scaffoldKey,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.white,
          titleSpacing: 0,
          title: Text(
            widget.appName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.fontColor,
            ),
          ),
        ),
        body: WillPopScope(
            onWillPop: onWillPop,
            child: Stack(
              children: <Widget>[
                WebViewWidget(
                    controller: WebViewController()
                      ..loadRequest(Uri.parse(widget.url!))
                      ..setJavaScriptMode(JavaScriptMode.unrestricted)
                      ..addJavaScriptChannel('Toaster', onMessageReceived: (message) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message.message)),
                        );
                      })
                      ..setNavigationDelegate(NavigationDelegate(
                        onPageFinished: (String url) {
                          setState(() {
                            isloading = false;
                          });
                        },
                        onNavigationRequest: (request) async {
                          return NavigationDecision.navigate;
                        },
                      ))),
                /* WebView(
                  initialUrl: widget.url,
                  javascriptMode: JavascriptMode.unrestricted,
                  onWebViewCreated: (WebViewController webViewController) {
                    _controller.complete(webViewController);
                  },
                  javascriptChannels: <JavascriptChannel>{
                    _toasterJavascriptChannel(context),
                  },
                  navigationDelegate: (NavigationRequest request) async {
                    if (request.url.startsWith(PAYPAL_RESPONSE_URL) ||
                        request.url.startsWith(FLUTTERWAVE_RES_URL)) {
                      if (mounted) {
                        setState(() {
                          isloading = true;
                        });
                      }

                      String responseurl = request.url;

                      if (responseurl.contains("Failed") || responseurl.contains("failed")) {
                        if (mounted) {
                          setState(() {
                            isloading = false;
                            message = "Transaction Failed";
                          });
                        }
                        Timer(const Duration(seconds: 1), () {
                          Navigator.pop(context);
                        });
                      } else if (responseurl.contains("Completed") ||
                          responseurl.contains("completed") ||
                          responseurl.toLowerCase().contains("success")) {
                        if (mounted) {
                          setState(() {
                            if (mounted) {
                              setState(() {
                                message = "Transaction Successfull";
                              });
                            }
                          });
                        }
                        List<String> testdata = responseurl.split("&");
                        for (String data in testdata) {
                          if (data.split("=")[0].toLowerCase() == "tx" ||
                              data.split("=")[0].toLowerCase() == "transaction_id") {
                            userProvider.setCartCount("0");

                            if (widget.from == "order") {
                              if (request.url.startsWith(PAYPAL_RESPONSE_URL)) {
                                Navigator.pushAndRemoveUntil(
                                    context,
                                    CupertinoPageRoute(
                                        builder: (BuildContext context) => const OrderSuccess()),
                                    ModalRoute.withName('/home'));
                              } else {
                                String txid = data.split("=")[1];
                                AddTransaction(txid, widget.orderId!, SUCCESS,
                                    'Order placed successfully', true);
                                //placeOrder(txid);
                                */
                /*setSnackbar('Transaction Successful',context);
                                if (mounted) {
                                  setState(() {
                                    isloading = false;
                                  });
                                }
                                Timer(const Duration(seconds: 1), () {
                                  Navigator.pop(context);
                                });*/
                /*
                              }
                            } else if (widget.from == "wallet") {
                              if (request.url.startsWith(FLUTTERWAVE_RES_URL)) {
                                String txid = data.split("=")[1];
                                setSnackbar('Transaction Successful', context);
                                if (mounted) {
                                  setState(() {
                                    isloading = false;
                                  });
                                }
                                Timer(const Duration(seconds: 1), () {
                                  Navigator.pop(context);
                                });

                                //sendRequest(txid, "flutterwave");
                              } else {
                                Navigator.of(context).pop();
                              }
                            }

                            break;
                          }
                        }
                      }

                      if (request.url.startsWith(PAYPAL_RESPONSE_URL) &&
                          widget.orderId != null &&
                          (responseurl.contains('Canceled-Reversal') ||
                              responseurl.contains('Denied') ||
                              responseurl.contains('Failed'))) deleteOrder();
                      return NavigationDecision.prevent;
                    }

                    return NavigationDecision.navigate;
                  },
                  onPageFinished: (String url) {
                    setState(() {
                      isloading = false;
                    });
                  },
                ),*/
                isloading
                    ? const Center(
                  child: CircularProgressIndicator(
                    color: colors.primary,
                  ),
                )
                    : const SizedBox(),
                message.trim().isEmpty
                    ? Container()
                    : Center(
                    child: Container(
                        color: colors.primary,
                        padding: const EdgeInsets.all(5),
                        margin: const EdgeInsets.all(5),
                        child: Text(
                          message,
                          style: TextStyle(color: Theme.of(context).colorScheme.white),
                        )))
              ],
            )));
  }

  Future<bool> onWillPop() {
    DateTime now = DateTime.now();

    Navigator.pop(context, 'true');
    return Future.value(true);
  }
}
