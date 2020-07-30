import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Donate extends StatefulWidget {
  @override
  _DonateState createState() => _DonateState();
}

class _DonateState extends State<Donate> {
  @override
  Widget build(BuildContext context) {

    Size size = MediaQuery.of(context).size;
    return SafeArea(
      child: Scaffold(
        appBar:AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: InkWell(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.keyboard_arrow_left,
              color: Colors.black,
              size: 62,
            ),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: <Widget>[
            Center(
              child: Image.asset(
                'assets/donate.jpg',
                fit: BoxFit.fitHeight,
                width: size.width,
                height: size.height,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Card(
                  margin: EdgeInsets.all(0.0),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 4,
                  color: Color(0x99000000),
                  child: Container(
                    height: size.height * 0.50,
                    padding: EdgeInsets.symmetric(vertical:8.0, horizontal: 8.0),
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: <Widget>[
                                  Text(
                                  "Donate",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                  SizedBox(
                                    width: 8,
                                  ),
                                  Text(
                                    "Every is dollar appreciated",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ]
                              ),


                              SizedBox(
                                height: 4,
                              ),

                              SizedBox(
                                width: size.width - 10,
                                height: size.height*0.5 - 115,
                                child: AutoSizeText(
                                  "Writing Software is hard work! It takes a lot of"
                                      " time to develop and maintain good software. "
                                      "I made this app FREE so that all can access "
                                      "the benefits in spite of your means. "
                                      "If this app has brought you joy and you would like"
                                      " to support the development of more features. "
                                      "Please click below.",
                                  style: TextStyle(
                                    fontSize: 29,
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(),
                        ),

                        Divider(
                          color: Colors.grey[200],
                        ),
                        InkWell(
                          onTap: () => _launchWeb(),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                              border: Border.all(color: Colors.grey),
                              color: Colors.red
                            ),
                            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
                            child: Center(
                              child: Text(
                                "DONATE!",
                                style: TextStyle(
                                    fontSize: 18,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          ),
                        ),
                        ],
                    ),
                  )
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
  _launchWeb() async {
    const url = 'http://bit.ly/1PAZqQ2';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
