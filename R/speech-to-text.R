#' Call Google Speech API
#'
#' Turn audio into text
#'
#' @param audio_source File location of audio data, or Google Cloud Storage URI
#' @param encoding Encoding of audio data sent
#' @param sampleRateHertz Sample rate in Hertz of audio data. Valid values \code{8000-48000}. Optimal and default if left \code{NULL} is \code{16000}
#' @param languageCode Language of the supplied audio as a \code{BCP-47} language tag
#' @param maxAlternatives Maximum number of recognition hypotheses to be returned. \code{0-30}
#' @param profanityFilter If \code{TRUE} will attempt to filter out profanities
#' @param speechContexts An optional character vector of context to assist the speech recognition
#' @param asynch If your \code{audio_source} is greater than 60 seconds, set this to TRUE to return an asynchronous call
#'
#' @return A list of two tibbles:  \code{$transcript}, a tibble of the \code{transcript} with a \code{confidence}; \code{$timings}, a tibble that contains \code{startTime}, \code{endTime} per \code{word}.  If maxAlternatives is greater than 1, then the transcript will return near-duplicate rows with other interpretations of the text.
#'  If \code{asynch} is TRUE, then an operation you will need to pass to \link{gl_speech_op} to get the finished result.
#'
#' @details
#'
#' Google Cloud Speech API enables developers to convert audio to text by applying powerful
#' neural network models in an easy to use API.
#' The API recognizes over 80 languages and variants, to support your global user base.
#' You can transcribe the text of users dictating to an application’s microphone,
#' enable command-and-control through voice, or transcribe audio files, among many other use cases.
#' Recognize audio uploaded in the request, and integrate with your audio storage on Google Cloud Storage,
#' by using the same technology Google uses to power its own products.
#'
#' @section AudioEncoding:
#'
#' Audio encoding of the data sent in the audio message. All encodings support only 1 channel (mono) audio.
#' Only FLAC and WAV include a header that describes the bytes of audio that follow the header.
#' The other encodings are raw audio bytes with no header.
#' For best results, the audio source should be captured and transmitted using a
#' lossless encoding (FLAC or LINEAR16).
#' Recognition accuracy may be reduced if lossy codecs, which include the other codecs listed in this section,
#' are used to capture or transmit the audio, particularly if background noise is present.
#'
#' Read more on audio encodings here \url{https://cloud.google.com/speech/docs/encoding}
#'
#' @section WordInfo:
#'
#'
#' \code{startTime} - Time offset relative to the beginning of the audio, and corresponding to the start of the spoken word.
#'
#' \code{endTime} - Time offset relative to the beginning of the audio, and corresponding to the end of the spoken word.
#'
#' \code{word} - The word corresponding to this set of information.
#'
#' @examples
#'
#' \dontrun{
#'
#' test_audio <- system.file("woman1_wb.wav", package = "googleLanguageR")
#' result <- gl_speech(test_audio)
#'
#' result$transcript
#' result$timings
#'
#' result2 <- gl_speech(test_audio, maxAlternatives = 2L)
#' result2$transcript
#'
#' result_brit <- gl_speech(test_audio, languageCode = "en-GB")
#'
#'
#' ## make an asynchronous API request (mandatory for sound files over 60 seconds)
#' asynch <- gl_speech(test_audio, asynch = TRUE)
#'
#' ## Send to gl_speech_op() for status or finished result
#' gl_speech_op(asynch)
#'
#' ## Upload to GCS bucket for long files > 60 seconds
#' test_gcs <- "gs://mark-edmondson-public-files/googleLanguageR/a-dream-mono.wav"
#' gcs <- gl_speech(test_gcs, sampleRateHertz = 44100L, asynch = TRUE)
#' gl_speech_op(gcs)
#' }
#'
#'
#' @seealso \url{https://cloud.google.com/speech/reference/rest/v1/speech/recognize}
#' @export
#' @import assertthat
#' @import base64enc
#' @importFrom googleAuthR gar_api_generator
#' @importFrom tibble as_tibble
gl_speech <- function(audio_source,
                      encoding = c("LINEAR16","FLAC","MULAW","AMR",
                                   "AMR_WB","OGG_OPUS","SPEEX_WITH_HEADER_BYTE"),
                      sampleRateHertz = NULL,
                      languageCode = "en-US",
                      maxAlternatives = 1L,
                      profanityFilter = FALSE,
                      speechContexts = NULL,
                      asynch = FALSE){

  if(is.null(sampleRateHertz)){
    my_message("Setting sampleRateHertz = 16000L")
    sampleRateHertz <- 16000L
  }
  assert_that(is.string(audio_source),
              is.string(languageCode),
              is.numeric(maxAlternatives),
              is.scalar(sampleRateHertz),
              is.logical(profanityFilter))

  encoding <- match.arg(encoding)

  if(is.gcs(audio_source)){
    recognitionAudio <- list(
      uri = audio_source
    )
  } else {
    assert_that(is.readable(audio_source))

    recognitionAudio <- list(
      content = base64encode(audio_source)
    )
  }

  body <- list(
    config = list(
      encoding = encoding,
      sampleRateHertz = sampleRateHertz,
      languageCode = languageCode,
      maxAlternatives = maxAlternatives,
      profanityFilter = profanityFilter,
      speechContexts = speechContexts,
      enableWordTimeOffsets = TRUE
    ),
    audio = recognitionAudio
  )

  ## asynch or normal call?
  if(asynch){
    call_api <- gar_api_generator("https://speech.googleapis.com/v1/speech:longrunningrecognize",
                                  "POST",
                                  data_parse_function = parse_async)

  } else {

    call_api <- gar_api_generator("https://speech.googleapis.com/v1/speech:recognize",
                                  "POST",
                                  data_parse_function = parse_speech)
  }

  call_api(the_body = body)

}

# parse normal speech call responses
parse_speech <- function(x){
  if(!is.null(x$totalBilledTime)){
    my_message("Speech transcription finished. Total billed time: ",
               x$totalBilledTime, level = 3)
  }

  transcript <-
    my_map_df(x$results$alternatives,
              ~ as_tibble(cbind(transcript = ifelse(!is.null(.x$transcript),
                                                             .x$transcript,NA),
                                confidence = ifelse(!is.null(.x$confidence),
                                                             .x$confidence,NA))))
  timings    <- my_map_df(x$results$alternatives,
                          ~ .x$words[[1]])

  list(transcript = transcript, timings = timings)
}

# parse asynchronous speech calls responses
parse_async <- function(x){

  if(is.null(x$done)){
    my_message("Speech transcription running")
    if(!is.null(x$metadata$startTime)){
      my_message("- started at ", x$metadata$startTime,
                 " - last update: ", x$metadata$lastUpdateTime,
                 level = 3)
    }
    return(structure(x, class = "gl_speech_op"))
  } else {
    my_message("Asychronous transcription finished.", level = 3)
  }

  parse_speech(x$response)

}

#' pretty print of gl_speech_op
#' @export
#' @keywords internal
#' @noRd
print.gl_speech_op <- function(x, ...){
  cat("## Send to gl_speech_op() for status")
  cat("\n##", x$name)
}

# checks if gl_speech_op class
is.gl_speech_op <- function(x){
  inherits(x, "gl_speech_op")
}

#' Get a speech operation
#'
#' For asynchronous calls of audio over 60 seconds, this returns the finished job
#'
#' @param operation A speech operation object from \link{gl_speech} when \code{asynch = TRUE}
#'
#' @return If the operation is still running, another operation object.  If done, the result as per \link{gl_speech}
#'
#' @seealso \link{gl_speech}
#' @export
#' @import assertthat
#' @examples
#'
#' \dontrun{
#'
#' test_audio <- system.file("woman1_wb.wav", package = "googleLanguageR")
#'
#' ## make an asynchronous API request (mandatory for sound files over 60 seconds)
#' asynch <- gl_speech(test_audio, asynch = TRUE)
#'
#' ## Send to gl_speech_op() for status or finished result
#' gl_speech_op(asynch)
#'
#' }
#'
gl_speech_op <- function(operation){

  assert_that(
    is.gl_speech_op(operation)
  )

  call_api <- gar_api_generator(sprintf("https://speech.googleapis.com/v1/operations/%s", operation$name),
                                "GET",
                                data_parse_function = parse_async)
  call_api()

}


