import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class About extends StatefulWidget {
  @override
  _AboutState createState() => _AboutState();
}

class _AboutState extends State<About> {
  @override
  Widget build(BuildContext context) {

    Size size = MediaQuery.of(context).size;
    print(size.width - 10);
    print(size.height*0.37 - 110);
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
                'assets/rohan.jpg',
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
                    height: size.height * 0.37,
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
                                children: <Widget>[
                                  /*CircleAvatar(
                                    radius: 36,
                                    backgroundImage: AssetImage("assets/rohan.jpg"),
                                  ),
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.all(Radius.circular(20)),
                                          border: Border.all(color: Colors.grey),
                                        ),
                                        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
                                        child: Center(
                                          child: Text(
                                            "Contact Me",
                                            style: TextStyle(
                                              fontSize: 14
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 8,
                                      )
                                    ],
                                  )*/
                                ],
                              ),
                              SizedBox(
                                height: 4,
                              ),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: <Widget>[
                                  Text(
                                  "Rohan A. Smith",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                  SizedBox(
                                    width: 8,
                                  ),
                                  Text(
                                    "App Developer",
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
                                height: size.height*0.37 - 115,
                                child: AutoSizeText(
                                    "I am a software developer for Mobile Apps and Websites. This project is my contribution to help you develop a closer relationship with the Lord. I pray you keep your heart pure and lift your praises high.",
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

                        Container(
                          height: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[

                              Container(
                                width: 110,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[

                                    Text(
                                      "Country",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    SizedBox(
                                      height: 4,
                                    ),

                                    Row(
                                      children: <Widget>[
                                        Text(
                                          "Jamaica ",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Image.asset('assets/flag.png',
                                          width: 32,
                                          height: 16,)
                                      ],
                                    ),

                                  ],
                                ),
                              ),

                              Container(
                                width: 80,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[

                                    Text(
                                      "Twitter",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    SizedBox(
                                      height: 4,
                                    ),

                                    Text(
                                      "@frazras",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                  ],
                                ),
                              ),

                              Container(
                                width: 90,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[

                                    Text(
                                      "Email",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    SizedBox(
                                      height: 1,
                                    ),

                                    Text(
                                      "rohan@ exterbox.com",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                              ],
                            ),
                          ),
                            ],
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
}
