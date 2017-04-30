# googleLanguageR - R client for the Google Translation API and Google Cloud Natural Language API

This package contains functions for analysing language through the [Google Cloud Machine Learning APIs](https://cloud.google.com/products/machine-learning/)

Note both are paid services, you will need to provide your credit card details for your own Google Project to use them.

## Google Cloud Translation API

> Google Cloud Translation API provides a simple programmatic interface for translating an arbitrary string into any supported language. Translation API is highly responsive, so websites and applications can integrate with Translation API for fast, dynamic translation of source text from the source language to a target language (e.g. French to English). 

Read more [here](https://cloud.google.com/translate/)

## Google Natural Language API

> Google Natural Language API reveals the structure and meaning of text by offering powerful machine learning models in an easy to use REST API. You can use it to extract information about people, places, events and much more, mentioned in text documents, news articles or blog posts. You can also use it to understand sentiment about your product on social media or parse intent from customer conversations happening in a call center or a messaging app. 

Read more [here](https://cloud.google.com/natural-language/)

## Translation API limits

The API limits in three ways: characters per day, characters per 100 seconds, and API requests per 100 seconds. All can be set in the API manager \code{https://console.developers.google.com/apis/api/translate.googleapis.com/quotas}

The library will limit the API calls for for the characters and API requests per 100 seconds, which you can set via the options `googleLanguageR.rate_limit` and `googleLanguageR.character_limit`.  By default these are set at `0.5` requests per second, and `100000` characters per 100 seconds.  Change them via:

```r
options(googleLanguageR.rate_limit = 0.15, 
        googleLanguageR.character_limit = 10000L)
```

