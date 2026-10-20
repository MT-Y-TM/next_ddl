#ifndef RUNNER_NEXT_DDL_FONTS_H_
#define RUNNER_NEXT_DDL_FONTS_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>

class NextDdlFonts {
 public:
  explicit NextDdlFonts(flutter::BinaryMessenger* messenger);
  ~NextDdlFonts();

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif
