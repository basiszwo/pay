# Example Rails controller for using Frisbii with the Pay gem
# This demonstrates common payment scenarios

class PaymentsController < ApplicationController
  before_action :authenticate_user!

  # Display payment form
  def new
    @plans = [
      { id: "monthly_basic", name: "Basic Monthly", price: 999 },
      { id: "monthly_pro", name: "Pro Monthly", price: 2999 },
      { id: "yearly_pro", name: "Pro Yearly", price: 29999 }
    ]
  end

  # Process one-time payment
  def create
    amount = params[:amount].to_i * 100 # Convert to cents

    begin
      # Ensure user has Frisbii as payment processor
      current_user.set_payment_processor :frisbii

      # Create the charge
      @charge = current_user.payment_processor.charge(
        amount,
        currency: "USD",
        description: params[:description],
        metadata: {
          product_name: params[:product_name],
          user_id: current_user.id
        }
      )

      # Send custom receipt if needed
      PaymentMailer.custom_receipt(@charge).deliver_later

      redirect_to payment_success_path, notice: "Payment successful!"
    rescue Pay::Frisbii::Error => e
      redirect_to payment_path, alert: "Payment failed: #{e.message}"
    end
  end

  # Start a subscription
  def subscribe
    plan_id = params[:plan_id]

    begin
      current_user.set_payment_processor :frisbii

      # Add payment method if token provided
      if params[:payment_token].present?
        payment_method = current_user.payment_processor.add_payment_method(
          params[:payment_token],
          default: true
        )
      end

      # Create subscription
      @subscription = current_user.payment_processor.subscribe(
        plan: plan_id,
        trial_period_days: params[:trial_days] || 0,
        metadata: {
          source: "web_signup",
          campaign: params[:campaign]
        }
      )

      redirect_to account_path, notice: "Subscription created successfully!"
    rescue Pay::Frisbii::Error => e
      redirect_to pricing_path, alert: "Subscription failed: #{e.message}"
    end
  end

  # Update payment method
  def update_payment_method
    begin
      payment_method = current_user.payment_processor.add_payment_method(
        params[:payment_token]
      )

      if params[:make_default] == "true"
        payment_method.make_default!
      end

      redirect_to account_path, notice: "Payment method updated"
    rescue Pay::Frisbii::Error => e
      redirect_to account_path, alert: "Failed to update payment method: #{e.message}"
    end
  end

  # Cancel subscription
  def cancel_subscription
    subscription = current_user.payment_processor.subscriptions.find(params[:id])

    if params[:immediately] == "true"
      subscription.cancel_now!
      message = "Subscription cancelled immediately"
    else
      subscription.cancel
      message = "Subscription will cancel at end of billing period"
    end

    redirect_to account_path, notice: message
  end

  # Resume cancelled subscription
  def resume_subscription
    subscription = current_user.payment_processor.subscriptions.find(params[:id])

    if subscription.on_grace_period?
      subscription.resume
      redirect_to account_path, notice: "Subscription resumed"
    else
      redirect_to account_path, alert: "Cannot resume this subscription"
    end
  end

  # Pause subscription
  def pause_subscription
    subscription = current_user.payment_processor.subscriptions.find(params[:id])

    pause_until = params[:resume_date] ? Date.parse(params[:resume_date]) : nil
    subscription.pause(until_date: pause_until)

    redirect_to account_path, notice: "Subscription paused"
  end

  # Change subscription plan
  def change_plan
    subscription = current_user.payment_processor.subscriptions.find(params[:id])
    new_plan = params[:new_plan_id]

    subscription.swap(new_plan, timing: params[:timing] || "immediate")

    redirect_to account_path, notice: "Plan changed successfully"
  end

  # Process refund
  def refund
    charge = current_user.payment_processor.charges.find(params[:charge_id])

    begin
      if params[:amount].present?
        # Partial refund
        refund_amount = (params[:amount].to_f * 100).to_i
        charge.refund!(refund_amount, reason: params[:reason])
      else
        # Full refund
        charge.refund!(reason: params[:reason])
      end

      redirect_to admin_charges_path, notice: "Refund processed"
    rescue Pay::Frisbii::Error => e
      redirect_to admin_charges_path, alert: "Refund failed: #{e.message}"
    end
  end

  # Generate customer portal session
  def customer_portal
    portal_session = current_user.payment_processor.billing_portal(
      return_url: account_url
    )

    redirect_to portal_session["url"]
  end

  # Generate checkout session
  def checkout
    session = current_user.payment_processor.checkout(
      mode: "payment",
      line_items: [{
        price: params[:price_id],
        quantity: 1
      }],
      success_url: payment_success_url,
      cancel_url: pricing_url
    )

    redirect_to session["url"]
  end

  # Success page after payment
  def success
    @charge = current_user.payment_processor.charges.last
  end

  private

  def ensure_payment_processor
    current_user.set_payment_processor :frisbii unless current_user.payment_processor
  end
end