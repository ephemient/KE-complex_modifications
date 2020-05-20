#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require_relative '../lib/karabiner.rb'

def remote_frontmost_application_if
  Karabiner.frontmost_application_if(
    %w[virtual_machine vnc remote_desktop],
    bundle_identifiers: %w[^com\.blade\.shadow-macos$],
  )
end
def remote_frontmost_application_unless
  Karabiner.frontmost_application_unless(
    %w[virtual_machine vnc remote_desktop],
    bundle_identifiers: %w[^com\.blade\.shadow-macos$],
  )
end

APPLE_VENDOR_ID = 1452
def apple_device_if
  {type: :device_if, identifiers: [{description: :Apple, vendor_id: APPLE_VENDOR_ID}]}
end
def apple_device_unless
  {type: :device_unless, identifiers: [{description: :Apple, vendor_id: APPLE_VENDOR_ID}]}
end

MICROSOFT_VENDOR_ID = 1118
MICROSOFT_KEYBOARD_PRODUCTS = {1936 => 'Wedge Mobile Keyboard'}.freeze
MICROSOFT_MOUSE_PRODUCTS = {1954 => 'Sculpt Comfort Mouse'}.freeze
def microsoft_keyboard_device_if
  {
    type: :device_if,
    identifiers: MICROSOFT_KEYBOARD_PRODUCTS.map do |id, desc|
      {description: "Microsoft #{desc}", vendor_id: MICROSOFT_VENDOR_ID, product_id: id}
    end,
  }
end
def microsoft_mouse_device_if
  {
    type: :device_if,
    identifiers: MICROSOFT_MOUSE_PRODUCTS.map do |id, desc|
      {description: "Microsoft #{desc}", vendor_id: MICROSOFT_VENDOR_ID, product_id: id}
    end,
  }
end

def command_option_swap_manipulators
  buttons = %i[left_command left_option right_command right_option]
  buttons.map.with_index do |button, i|
    {
      type: :basic,
      from: {key_code: button, modifiers: {optional: %i[any]}},
      to: [{key_code: buttons[i ^ 1]}],
    }
  end
end

def main
  puts JSON.pretty_generate(
    title: 'Personal rules (@ephemient)',
    rules: [
      {
        description: 'Function keys below touchbar',
        manipulators: [*1..9, 0, :hyphen, :equal_sign].flat_map.with_index do |key, i|
          [
            {
              type: :basic,
              conditions: [{type: :variable_if, name: :alternate_mode, value: 1}],
              from: {key_code: key.to_s, modifiers: {optional: %i[any]}},
              to: [{key_code: "f#{i + 1}"}],
            },
            {
              type: :basic,
              from: {key_code: key.to_s, modifiers: {mandatory: %i[fn], optional: %i[any]}},
              to: [{key_code: "f#{i + 1}", modifiers: %i[fn]}],
            },
          ]
        end,
      },
      {
        description: 'Double Shift to Caps Lock (or mouse keys)',
        manipulators: [
          {
            type: :basic,
            from: {
              simultaneous: [{key_code: :left_shift}, {key_code: :right_shift}],
              simultaneous_options: {detect_key_down_uninterruptedly: true, key_up_when: :all},
              modifiers: {optional: %i[any]},
            },
            to_if_alone: [{key_code: :caps_lock, hold_down_milliseconds: 200}],
            to: {set_variable: {name: :alternate_mode, value: 1}},
            to_after_key_up: {set_variable: {name: :alternate_mode, value: 0}},
          },
          *%i[left_shift right_shift].flat_map { |button|
            button_pressed = "#{button}_pressed"
            [
              {
                type: :basic,
                conditions: [{type: :variable_if, name: button_pressed, value: 1}],
                from: {key_code: button, modifiers: {optional: %i[any]}},
                to: [
                  {set_variable: {name: button_pressed, value: 0}},
                  {set_variable: {name: :alternate_mode, value: 1}},
                ],
                to_after_key_up: {set_variable: {name: :alternate_mode, value: 0}},
              },
              {
                type: :basic,
                from: {key_code: button, modifiers: {optional: %i[any]}},
                to: [{key_code: button}],
                to_if_alone: [{set_variable: {name: button_pressed, value: 1}}],
                to_delayed_action: {
                  to_if_canceled: [{set_variable: {name: button_pressed, value: 0}}],
                  to_if_invoked: [{set_variable: {name: button_pressed, value: 0}}],
                },
              },
            ]
          },
          *{
            button1: %i[spacebar return_or_enter],
            button2: %i[left_control right_control caps_lock],
            button3: %i[left_command left_option right_option right_command],
          }.flat_map do |button, keys|
            keys.map do |key|
              {
                type: :basic,
                conditions: [{type: :variable_if, name: :alternate_mode, value: 1}],
                from: {key_code: key, modifiers: {optional: %i[any]}},
                to: [{pointing_button: button}],
              }
            end
          end,
          *{
            w: {y: -1536}, d: {x: 1536}, a: {x: -1536}, s: {y: 1536},
            h: {horizontal_wheel: -48}, l: {horizontal_wheel: 48},
            j: {vertical_wheel: -48}, k: {vertical_wheel: 48},
            f: {speed_multiplier: 2.0}, g: {speed_multiplier: 0.5},
          }.map do |key, mouse|
            {
              type: :basic,
              conditions: [{type: :variable_if, name: :alternate_mode, value: 1}],
              from: {key_code: key, modifiers: {mandatory: %i[any]}},
              to: {mouse_key: mouse},
            }
          end,
          {
            type: :basic,
            conditions: [{type: :variable_if, name: :alternate_mode, value: 1}],
            from: {key_code: :fn, modifiers: {optional: %i[any]}},
            to: [{key_code: :fn}],
          },
          {
            type: :basic,
            conditions: [{type: :variable_if, name: :alternate_mode, value: 1}],
            from: {any: :key_code, modifiers: {optional: %i[any]}},
            to: [],
          },
        ],
      },
      {
        description: 'Application to Option on Microsoft keyboards',
        manipulators: [
          {
            type: :basic,
            conditions: [microsoft_keyboard_device_if, remote_frontmost_application_unless],
            from: {key_code: :application},
            to: [{key_code: :right_option}],
          },
        ],
      },
      {
        description: 'Microsoft mouse button to Mission Control',
        manipulators: [
          {
            type: :basic,
            conditions: [microsoft_mouse_device_if, remote_frontmost_application_unless],
            from: {key_code: :left_command, modifiers: {mandatory: %i[control]}},
            to_if_alone: [{key_code: :dashboard}],
          },
          {
            type: :basic,
            parameters: {:'basic.to_if_held_down_threshold_milliseconds' => 250},
            conditions: [microsoft_mouse_device_if, remote_frontmost_application_unless],
            from: {key_code: :left_command, modifiers: {optional: %i[any]}},
            to_if_alone: [{key_code: :mission_control}],
            to_if_held_down: [{key_code: :mission_control}],
          },
          {
            type: :basic,
            conditions: [microsoft_mouse_device_if, remote_frontmost_application_unless],
            from: {key_code: :tab, modifiers: {mandatory: %i[left_control any]}},
            to: [{key_code: :left_arrow, modifiers: %i[control]}],
          },
          {
            type: :basic,
            conditions: [microsoft_mouse_device_if, remote_frontmost_application_unless],
            from: {key_code: :delete_or_backspace, modifiers: {mandatory: %i[left_control any]}},
            to: [{key_code: :right_arrow, modifiers: %i[control]}],
          },
        ],
      },
      {
        description: 'Side buttons to Mission Control',
        manipulators: [
          {
            type: :basic,
            conditions: [apple_device_unless, remote_frontmost_application_unless],
            from: {
              simultaneous: [{pointing_button: :button4}, {pointing_button: :button5}],
              modifiers: {optional: %i[any]},
            },
            to: [{key_code: :mission_control}],
          },
          {
            type: :basic,
            conditions: [apple_device_unless, remote_frontmost_application_unless],
            from: {pointing_button: :button4, modifiers: {optional: %i[any]}},
            to: [{key_code: :left_arrow, modifiers: %i[control]}],
          },
          {
            type: :basic,
            conditions: [apple_device_unless, remote_frontmost_application_unless],
            from: {pointing_button: :button5, modifiers: {optional: %i[any]}},
            to: [{key_code: :right_arrow, modifiers: %i[control]}],
          },
        ],
      },
      {
        description: 'Caps Lock to Left Control (or Escape)',
        manipulators: [
          {
            type: :basic,
            conditions: [remote_frontmost_application_unless],
            from: {key_code: :caps_lock},
            to: [{key_code: :left_control, lazy: true}],
            to_if_alone: [{key_code: :escape}],
          },
          {
            type: :basic,
            from: {key_code: :caps_lock, modifiers: {optional: %i[any]}},
            to: [{key_code: :left_control}],
          },
        ],
      },
      {
        description: 'Alt/GUI to Command/Option on non-Apple keyboards',
        manipulators: command_option_swap_manipulators.map do |manipulator|
          manipulator.merge({
            conditions: [apple_device_unless, remote_frontmost_application_unless],
          })
        end,
      },
      {
        description: 'Command/Option to Alt/GUI to Command/Option when remote',
        manipulators: command_option_swap_manipulators.map do |manipulator|
          manipulator.merge({
            conditions: [apple_device_if, remote_frontmost_application_if],
          })
        end,
      },
    ],
  )
end

main
